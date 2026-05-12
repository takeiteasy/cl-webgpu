#!/usr/bin/env ruby

require 'uri'
require 'securerandom'
require 'rbconfig'
require 'json'
require 'fileutils'
require 'set'
require 'thread'

LOCK_FILE = 'dependencies.lock'
DEPS_DIR = 'deps'

# --- CLI parsing ---
force_all = false
forced_repos = Set.new
CLEAN = false
LIST = false

i = 0
while i < ARGV.length
  case ARGV[i]
  when '--force', '-f'
    i += 1
    while i < ARGV.length && !ARGV[i].start_with?('-')
      forced_repos << ARGV[i]
      i += 1
    end
    force_all = forced_repos.empty?
  when '--clean', '-c'
    CLEAN = true
    i += 1
  when '--list', '-l'
    LIST = true
    i += 1
  else
    i += 1
  end
end

if CLEAN
  puts "Cleaning dependencies..."
  FileUtils.rm_rf(DEPS_DIR) if Dir.exist?(DEPS_DIR)
  File.delete(LOCK_FILE) if File.exist?(LOCK_FILE)
end

# --- helpers ---

def git_latest_commit(repo_url, branch)
  repo_path = repo_url.gsub('.git', '') + '.git' if repo_url.include?('github')
  repo_path ||= repo_url
  cmd = "git ls-remote #{repo_path} #{branch}"
  result = `#{cmd}`.strip
  if $?.success?
    result.split("\t").first
  else
    puts "Error running git ls-remote command"
    nil
  end
rescue StandardError => e
  puts "Error fetching commit: #{e.message}"
  nil
end

def is_windows?
  RbConfig::CONFIG['host_os'] =~ /mswin|mingw|cygwin/
end

def temp_dir
  if is_windows?
    'C:\\Windows\\Temp\\'
  else
    '/tmp/'
  end
end

def separator
  is_windows? ? '\\' : '/'
end

def rnd_temp_dir
  temp_dir + SecureRandom.uuid
end

def load_lock
  return {} unless File.exist?(LOCK_FILE)
  data = JSON.parse(File.read(LOCK_FILE))
  # Normalize old format (string commit) or format without files
  data.each do |name, val|
    if val.is_a?(String)
      data[name] = { 'commit' => val, 'files' => [] }
    elsif val.is_a?(Hash) && !val.key?('files')
      data[name]['files'] = []
    end
  end
  data
rescue JSON::ParserError => e
  puts "Warning: failed to parse #{LOCK_FILE}: #{e.message}"
  {}
end

def save_lock(lock)
  File.write(LOCK_FILE, JSON.pretty_generate(lock) + "\n")
end

def print_and_run(cmd)
  puts cmd
  system(cmd)
end

def log_and_run(cmd, mutex)
  mutex.synchronize { puts cmd }
  system(cmd)
end

def remove_empty_parents(path)
  dir = File.dirname(path)
  while dir.start_with?(DEPS_DIR) && dir != DEPS_DIR
    if Dir.exist?(dir) && Dir.empty?(dir)
      Dir.rmdir(dir)
    else
      break
    end
    dir = File.dirname(dir)
  end
end

# --- package definitions ---
# Add `commit: "<sha>"` to pin a dependency to a specific revision.
packages = [
  {
    name: 'webgpu-headers',
    repo: 'https://github.com/webgpu-native/webgpu-headers',
    branch: 'main',
    include: [
      ['webgpu.h!', 'deps/webgpu'],
      ['webgpu.h!', 'deps/wgpu-native/ffi/webgpu-headers'],
    ]
  },
  {
    name: 'wgpu-native',
    repo: 'https://github.com/gfx-rs/wgpu-native',
    branch: 'trunk',
    include: [
      'Cargo.toml',
      'Cargo.lock',
      'build.rs',
      'rust-toolchain.toml',
      'src/*.rs',
      'ffi/wgpu.h',
      ['ffi/wgpu.h!', 'deps/webgpu'],
    ],
    patches: [
      'patches/wgpu-native-wgpu.h.patch'
    ]
  },
  {
    name: 'glfw',
    repo: 'https://github.com/glfw/glfw',
    branch: 'master',
    include: [
      'include/GLFW/*.h',
      'src/*.{c,m,h}',
      'src/CMakeLists.txt',
      'src/mappings.h.in',
      'CMakeLists.txt',
      'CMake/*.cmake',
      'CMake/*.cmake.in',
      'CMake/*.pc.in'
    ],
    exclude: [
      'src/win32*',
      'src/wgl_context.c',
      'src/wl_*',
    ]
  },
  {
    name: 'glfw3webgpu',
    repo: 'https://github.com/eliemichel/glfw3webgpu',
    branch: 'main',
    include: [
      'glfw3webgpu.{c,h}',
      'CMakeLists.txt'
    ]
  }
]

# --- list mode ---
if LIST
  lock = load_lock
  packages.each do |pkg|
    name = pkg[:name]
    branch = pkg[:branch] || "master"
    pinned = pkg[:commit]
    entry = lock[name] || {}
    cached = entry.is_a?(Hash) ? entry['commit'] : entry

    if pinned
      status = if cached == pinned
        "pinned (#{pinned[0..7]})"
      else
        "out of date (pinned: #{pinned[0..7]}, cached: #{cached ? cached[0..7] : 'none'})"
      end
    else
      latest = git_latest_commit(pkg[:repo], branch)
      if latest
        status = if cached == latest
          "up to date (#{latest[0..7]})"
        else
          "out of date (latest: #{latest[0..7]}, cached: #{cached ? cached[0..7] : 'none'})"
        end
      else
        status = "failed to check"
      end
    end
    puts "#{name}: #{status}"
  end
  exit 0
end

# --- main update loop ---
lock = load_lock
mutex = Mutex.new
threads = []

packages.each do |pkg|
  threads << Thread.new(pkg) do |p|
    name = p[:name]
    tmp_path = nil
    begin
      branch = p[:branch] || "master"
      pinned_commit = p[:commit]

      old_entry = lock[name] || { 'commit' => nil, 'files' => [] }
      old_commit = old_entry['commit']
      old_files = old_entry['files'] || []

      target_commit = nil
      needs_update = false
      logs = []

      if pinned_commit
        target_commit = pinned_commit
        if old_commit != target_commit
          logs << "Updating #{name} to pinned commit #{target_commit[0..7]}"
          needs_update = true
        end
      else
        target_commit = git_latest_commit(p[:repo], branch)
        unless target_commit
          mutex.synchronize { puts "Failed to fetch latest commit for #{name}, skipping" }
          next
        end
        if old_commit != target_commit
          logs << "Updating #{name} to #{target_commit[0..7]}"
          needs_update = true
        end
      end

      if !needs_update && old_files.any? { |f| !File.exist?(f) }
        logs << "Redownloading #{name} - missing files detected"
        needs_update = true
      end

      is_forced = force_all || forced_repos.include?(name)
      if is_forced && !needs_update
        logs << "Force updating #{name} to #{target_commit[0..7]}"
        needs_update = true
      end

      unless needs_update
        mutex.synchronize { puts "Skipping #{name} - up to date (#{target_commit[0..7]})" }
        next
      end

      mutex.synchronize { logs.each { |l| puts l } }

      tmp_path = rnd_temp_dir

      if pinned_commit
        log_and_run("git init #{tmp_path}", mutex)
        log_and_run("git -C #{tmp_path} remote add origin #{p[:repo]}", mutex)
        cmd = "git -C #{tmp_path} fetch --depth 1 origin #{target_commit}"
        mutex.synchronize { puts cmd }
        fetched = system(cmd)
        unless fetched
          mutex.synchronize { puts "Shallow fetch failed, trying full fetch..." }
          cmd = "git -C #{tmp_path} fetch origin #{target_commit}"
          mutex.synchronize { puts cmd }
          fetched = system(cmd)
        end
        unless fetched
          mutex.synchronize { puts "Failed to fetch commit #{target_commit} for #{name}" }
          FileUtils.rm_rf(tmp_path)
          tmp_path = nil
          next
        end
        log_and_run("git -C #{tmp_path} checkout FETCH_HEAD", mutex)
      else
        log_and_run("git clone --depth 1 --branch #{branch} #{p[:repo]} #{tmp_path}", mutex)
      end

      if p[:submodules]
        log_and_run("git -C #{tmp_path} submodule update --init --recursive", mutex)
      end

      copies = []
      new_files = []

      p[:include].each do |pattern|
        pat, d = pattern.is_a?(String) ? [pattern, "deps#{separator}#{p[:name]}"] : pattern
        flatten = pat.end_with?('!')
        pat = pat.chomp('!') if flatten
        Dir.glob("#{tmp_path}#{separator}#{pat}").each do |src_file|
          if p[:exclude]
            rel_path = src_file.sub("#{tmp_path}#{separator}", "")
            next if p[:exclude].any? { |ex| File.fnmatch?(ex, rel_path, File::FNM_PATHNAME) }
          end

          dest = flatten ? "#{d}#{separator}#{File.basename(src_file)}" : src_file.sub("#{tmp_path}#{separator}", "#{d}#{separator}")
          copies << [src_file, dest]
          new_files << dest
        end
      end

      mutex.synchronize do
        copies.each do |src_file, dest|
          if Dir.exist?(src_file)
            print_and_run("cp -r #{src_file} #{dest}")
          else
            dest_dir = File.dirname(dest)
            print_and_run("mkdir -p #{dest_dir}") unless Dir.exist?(dest_dir)
            print_and_run("cp #{src_file} #{dest}")
          end
        end

        # Apply any post-copy patches
        (p[:patches] || []).each do |patch_file|
          unless File.exist?(patch_file)
            puts "Warning: patch file #{patch_file} not found, skipping"
            next
          end
          result = system("patch -p1 --forward --fuzz=3 --reject-file=- < #{patch_file} 2>/dev/null")
          if result
            puts "Applied patch #{patch_file}"
          else
            puts "Note: patch #{patch_file} did not apply (may already be applied or upstream changed)"
          end
        end

        # Remove orphaned files from previous installs
        orphans = (old_files - new_files).uniq
        orphans.each do |orphan|
          if File.file?(orphan)
            File.delete(orphan)
            puts "Removed orphaned file: #{orphan}"
            remove_empty_parents(orphan)
          elsif File.directory?(orphan)
            FileUtils.rm_rf(orphan)
            puts "Removed orphaned directory: #{orphan}"
            remove_empty_parents(orphan)
          end
        end

        FileUtils.rm_rf(tmp_path)
        tmp_path = nil
        lock[name] = { 'commit' => target_commit, 'files' => new_files }
      end
    rescue StandardError => e
      mutex.synchronize { puts "Error processing #{name}: #{e.message}" }
    ensure
      FileUtils.rm_rf(tmp_path) if tmp_path && File.exist?(tmp_path)
    end
  end
end

threads.each(&:join)
save_lock(lock)
