require "test_helper"

class GitResourceTest < ActiveSupport::TestCase
  setup do
    SearchIndex.reset!

    @root = Dir.mktmpdir("uris-git-root")
    @origin = Dir.mktmpdir("uris-git-origin")

    ENV["URIS_GIT_ROOT"] = @root
    ENV["URIS_GIT_PROTOCOLS"] = "file"

    build_origin

    @tenant = Tenant.create!(subdomain: "git-#{SecureRandom.hex(4)}", name: "Git")

    Tenant.switch(@tenant) do
      @resource = Resource::Git.create!(
        key: "widgets", name: "Widgets",
        details: { "url" => "file://#{@origin}", "ref" => "main" }
      )
    end
  end

  teardown do
    ENV.delete("URIS_GIT_ROOT")
    ENV.delete("URIS_GIT_PROTOCOLS")

    FileUtils.remove_entry(@root, true)
    FileUtils.remove_entry(@origin, true)
  end

  test "the stored type is git, and it syncs" do
    assert_equal "git", @resource.type
    assert @resource.syncable?

    Tenant.switch(@tenant) { assert_instance_of Resource::Git, Resource.find(@resource.id) }
  end

  test "check reaches the repository and finds a branch" do
    Tenant.switch(@tenant) { assert @resource.check! }
  end

  test "a repository that is not there fails rather than raising something raw" do
    Tenant.switch(@tenant) do
      @resource.update!(details: @resource.details.merge("url" => "file:///nowhere/at/all.git"))

      assert_raises(Resource::Failed) { @resource.check! }
    end
  end

  test "every file at the tip becomes an item keyed on its path" do
    Tenant.switch(@tenant) { SyncResourceJob.perform_now(@tenant.id, @resource.id) }

    Tenant.switch(@tenant) do
      keys = Feed.all.map(&:locator_key).sort

      assert_equal %w[README.md lib/widget.rb], keys
      assert_equal "text/plain", feed_at("lib/widget.rb").mime, "source is text, not an unknown file"
    end
  end

  test "the bytes come back out of the clone rather than another fetch" do
    Tenant.switch(@tenant) do
      @resource.each_page { |_batch, _cursor| nil }

      entry = @resource.send(:entries, nil).find { |held| held.path == "lib/widget.rb" }

      assert_equal "class Widget\nend\n", @resource.download(@resource.locator_for(entry)).read
    end
  end

  test "a changed file is a new version, so it is analyzed again" do
    Tenant.switch(@tenant) { SyncResourceJob.perform_now(@tenant.id, @resource.id) }

    before = Tenant.switch(@tenant) { Reference.find_by!(locator_key: "README.md").version }

    commit("README.md", "# Widgets\n\nNow with more widgets.\n")

    Tenant.switch(@tenant) { SyncResourceJob.perform_now(@tenant.id, @resource.id) }

    after = Tenant.switch(@tenant) { Reference.find_by!(locator_key: "README.md").reload }

    assert_not_equal before, after.version
    assert_nil after.analyzed_at, "a changed blob has to be read again"
  end

  test "a sync resumes after the path it stopped at" do
    seen = []

    Tenant.switch(@tenant) do
      @resource.each_page(cursor: "README.md") { |batch, _| seen += batch.map(&:path) }
    end

    assert_equal [ "lib/widget.rb" ], seen
  end

  test "a blob larger than the cap is left out rather than pulled into the catalogue" do
    commit("big.bin", "x" * (Resource::Git::MAX_BLOB + 1))

    Tenant.switch(@tenant) { SyncResourceJob.perform_now(@tenant.id, @resource.id) }

    Tenant.switch(@tenant) do
      assert_not_includes Feed.all.map(&:locator_key), "big.bin"
    end
  end

  test "a prefix narrows the walk to one directory" do
    found = Tenant.switch(@tenant) { @resource.command(:list, prefix: "lib") }

    assert_equal [ "lib/widget.rb" ], found["files"].map { |file| file["path"] }
  end

  test "a protocol the operator did not allow is refused, and the default is https alone" do
    ENV["URIS_GIT_PROTOCOLS"] = "https"

    Tenant.switch(@tenant) do
      error = assert_raises(Resource::Unusable) { @resource.check! }

      assert_match(/URIS_GIT_PROTOCOLS/, error.message)
    end

    ENV.delete("URIS_GIT_PROTOCOLS")

    assert_equal [ "https" ], Resource::Git.protocols
  end

  test "an ext:: url, which would run a command, is not a url git is ever handed" do
    ENV["URIS_GIT_PROTOCOLS"] = "https"

    Tenant.switch(@tenant) do
      %w[ext::sh ext::sh\ -c\ whoami file:///etc git://example.test/r.git].each do |url|
        resource = Resource::Git.new(key: "evil", details: { "url" => url })

        assert_not resource.valid?, "#{url} must not be a repository this can be pointed at"
      end
    end
  end

  test "a repository inside the network is refused before git is asked to dial it" do
    ENV["URIS_GIT_PROTOCOLS"] = "https"

    Tenant.switch(@tenant) do
      resource = Resource::Git.new(key: "meta",
                                   details: { "url" => "https://169.254.169.254/repo.git" })

      assert_not resource.valid?
    end
  end

  test "a clone lives under its tenant by id, so no key can put it anywhere else" do
    Tenant.switch(@tenant) do
      @resource.update!(key: "../../../../tmp/escaped")

      assert_equal File.join(@root, @tenant.id.to_s, "#{@resource.id}.git"), @resource.working_dir
    end
  end

  test "a url carrying credentials is refused, since listing the resource would show them" do
    ENV["URIS_GIT_PROTOCOLS"] = "https"

    Tenant.switch(@tenant) do
      resource = Resource::Git.new(key: "leaky",
                                   details: { "url" => "https://x:ghp_secret@github.com/acme/widgets.git" })

      assert_not resource.valid?
      assert_match(/token/, resource.errors.full_messages.join)
    end
  end

  test "git dials the address that was vetted and follows no redirect off it" do
    ENV["URIS_GIT_PROTOCOLS"] = "https"
    dialled = []

    Tenant.switch(@tenant) do
      @resource.update!(details: { "url" => "https://git.example.test/acme/widgets.git" })
      @resource.define_singleton_method(:capture) do |_env, command, _binary|
        dialled << command
        [ "0123abcd\trefs/heads/main\n", "", Struct.new(:success?).new(true) ]
      end

      @resource.check!
    end

    command = dialled.first.join(" ")

    assert_includes command, "http.followRedirects=false"
    assert_includes command, "http.curloptResolve=git.example.test:443:#{Offline::PUBLIC}"
  end

  test "git that runs past its time is stopped rather than holding the worker" do
    Tenant.switch(@tenant) do
      error = with_timeout(0) { assert_raises(Resource::Failed) { @resource.check! } }

      assert_match(/ran past/, error.message)
    end
  end

  test "with no clone root set the type says so rather than writing somewhere" do
    ENV.delete("URIS_GIT_ROOT")

    Tenant.switch(@tenant) do
      error = assert_raises(Resource::Unusable) { @resource.each_page { |_, _| nil } }

      assert_match(/URIS_GIT_ROOT/, error.message)
    end
  end

  test "a token never reaches the command line or the stored config" do
    Tenant.switch(@tenant) do
      @resource.update!(credentials: { "token" => "ghp_secret_value" })

      @resource.each_page { |_batch, _cursor| nil }

      config = File.read(File.join(@resource.working_dir, "config"))

      assert_not_includes config, "ghp_secret_value"
      assert_not_includes config, "url ="
    end
  end

  private

    def build_origin
      sh("git", "init", "--quiet", "--initial-branch", "main", @origin)
      sh("git", "-C", @origin, "config", "user.email", "test@uris.test")
      sh("git", "-C", @origin, "config", "user.name", "uris")

      place("README.md", "# Widgets\n")
      place("lib/widget.rb", "class Widget\nend\n")

      sh("git", "-C", @origin, "add", "-A")
      sh("git", "-C", @origin, "commit", "--quiet", "-m", "first")
    end

    def commit(path, body)
      place(path, body)
      sh("git", "-C", @origin, "add", "-A")
      sh("git", "-C", @origin, "commit", "--quiet", "-m", "change #{path}")
    end

    def place(path, body)
      full = File.join(@origin, path)
      FileUtils.mkdir_p(File.dirname(full))
      File.write(full, body)
    end

    def sh(*args)
      _out, err, status = Open3.capture3(*args)

      raise "#{args.join(' ')} failed: #{err}" unless status.success?
    end

    def with_timeout(seconds)
      held = Resource::Git::TIMEOUT
      Resource::Git.send(:remove_const, :TIMEOUT)
      Resource::Git.const_set(:TIMEOUT, seconds)
      yield
    ensure
      Resource::Git.send(:remove_const, :TIMEOUT)
      Resource::Git.const_set(:TIMEOUT, held)
    end
end
