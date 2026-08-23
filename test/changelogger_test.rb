# changelogger_test.rb

# 20260823

# The revisions under test are built rather than borrowed.  changelogger reads a
# directory of numbered subdirectories, each holding a binary, and both are made
# here per example, so that every tier and every diff it draws is stated outright
# rather than being whichever states the tools staged beside it happen to hold.
#
# Run as a subprocess and asserted upon by the CHANGELOG it wrote, the revisions
# root being the whole of the interface and already there.

require 'fileutils'
require 'minitest/autorun'
require 'rbconfig'
require 'tmpdir'

# CHANGELOGGER points the suite at another revision, which is how the extractor
# examples were confirmed to fail against 0.10.1 rather than merely to pass here.
TOOL = ENV['CHANGELOGGER'] || File.expand_path('../bin/changelogger', __dir__)

# A method whose body holds a modifier, which carries no end.  Under 0.10.1 the
# depth count read it as opening a block and ran to the end of the file, so this
# method was reported as altered whenever anything below it changed.
MODIFIER_METHOD = <<~RUBY
  def guarded(value)
    return nil if value.nil?
    value.to_s
  end
RUBY

PLAIN_METHOD = <<~RUBY
  def plain(value)
    value
  end
RUBY

describe "changelogger" do
  before do
    @root = Dir.mktmpdir('changelogger')
  end

  after do
    FileUtils.remove_entry(@root)
  end

  def script(version, body, name: 'thing', changes: nil)
    header = "#!/usr/bin/env ruby\n# #{name}\n\n# 20260823\n# #{version}\n"
    header += changes.to_s
    "#{header}\n#{body}"
  end

  def revision(number, source, name: 'thing')
    directory = File.join(@root, number.to_s, 'bin')
    FileUtils.mkdir_p(directory)
    File.write(File.join(directory, name), source)
  end

  # A library keeps its header in lib/, named for the project rather than sitting in
  # bin/.  The revisions root is a temporary directory, so its basename is what a
  # library file must be named to be found without being pointed at.
  def library_revision(number, source, name: File.basename(@root))
    directory = File.join(@root, number.to_s, 'lib')
    FileUtils.mkdir_p(directory)
    File.write(File.join(directory, "#{name}.rb"), source)
  end

  def run_changelogger(*arguments)
    output = IO.popen([RbConfig.ruby, TOOL, *arguments, @root], err: [:child, :out], &:read)
    [output, $?.exitstatus]
  end

  def changelog(number)
    path = File.join(@root, number.to_s, 'CHANGELOG')
    File.exist?(path) ? File.read(path) : nil
  end

  # Tier 3, which has nothing to diff against and says what is present.
  it "inventories the first revision" do
    revision(0, script('0.0.0', PLAIN_METHOD))
    run_changelogger
    _(changelog(0)).must_include '+ plain()'
  end

  # Tier 1, which is used as written and is the reason a Changes section is
  # worth carrying.
  it "takes a Changes section as written" do
    revision(0, script('0.0.0', PLAIN_METHOD))
    revision(1, script('0.1.0', PLAIN_METHOD + MODIFIER_METHOD, changes: "# Changes since 0.0:\n# 1. + guarded(), for the empty case.\n"))
    run_changelogger
    _(changelog(1)).must_include '+ guarded(), for the empty case.'
  end

  # Tier 2, which reads the structure where there is no Changes section.
  it "reports a method added" do
    revision(0, script('0.0.0', PLAIN_METHOD))
    revision(1, script('0.1.0', PLAIN_METHOD + MODIFIER_METHOD))
    run_changelogger
    _(changelog(1)).must_include '+ guarded()'
  end

  it "reports a method removed" do
    revision(0, script('0.0.0', PLAIN_METHOD + MODIFIER_METHOD))
    revision(1, script('0.1.0', PLAIN_METHOD))
    run_changelogger
    _(changelog(1)).must_include '- guarded()'
  end

  it "reports a method whose body changed" do
    revision(0, script('0.0.0', PLAIN_METHOD))
    revision(1, script('0.1.0', "def plain(value)\n  value.to_s\nend\n"))
    run_changelogger
    _(changelog(1)).must_include '~ plain()'
  end

  # The fault 0.11.0 fixed.  guarded() is untouched between the two revisions;
  # what changed is a method added after it.  Under 0.10.1 the extraction of
  # guarded() ran past its own end and into that addition, so it was reported as
  # altered.
  it "leaves a method holding a modifier alone where only what follows it changed" do
    revision(0, script('0.0.0', MODIFIER_METHOD))
    revision(1, script('0.1.0', MODIFIER_METHOD + PLAIN_METHOD))
    run_changelogger
    _(changelog(1)).wont_include '~ guarded()'
    _(changelog(1)).must_include '+ plain()'
  end

  # The same for the other modifiers, each of which carries no end.
  it "leaves a method holding unless, while or until alone likewise" do
    body = "def qualified(value)\n  return value unless value.nil?\n  value = nil while false\n  value = nil until true\n  value\nend\n"
    revision(0, script('0.0.0', body))
    revision(1, script('0.1.0', body + PLAIN_METHOD))
    run_changelogger
    _(changelog(1)).wont_include '~ qualified()'
  end

  # A do which ends the line opens a block and its end closes it, so a method
  # holding one is read no further than its own end either.
  it "reads a method holding a block to its own end" do
    body = "def iterating(values)\n  values.each do |value|\n    puts value\n  end\nend\n"
    revision(0, script('0.0.0', body))
    revision(1, script('0.1.0', body + PLAIN_METHOD))
    run_changelogger
    _(changelog(1)).wont_include '~ iterating()'
  end

  it "writes a cumulative CHANGELOG, the newest entry first" do
    revision(0, script('0.0.0', PLAIN_METHOD))
    revision(1, script('0.1.0', PLAIN_METHOD + MODIFIER_METHOD))
    run_changelogger
    _(changelog(1).index('0.1.0')).must_be :<, changelog(1).index('0.0.0')
  end

  # A generated entry rewritten by hand is not overwritten upon a later run,
  # which is what makes the output a starting point rather than a record kept.
  it "skips a revision which already has a CHANGELOG" do
    revision(0, script('0.0.0', PLAIN_METHOD))
    File.write(File.join(@root, '0', 'CHANGELOG'), "# CHANGELOG\n\nwritten by hand\n")
    run_changelogger
    _(changelog(0)).must_include 'written by hand'
  end

  it "reports a change of the program name, which the structure alone does not carry" do
    revision(0, script('0.0.0', PLAIN_METHOD, name: 'thing'))
    revision(1, script('0.1.0', PLAIN_METHOD, name: 'other'), name: 'other')
    run_changelogger
    _(changelog(1)).must_include '/thing/other/'
  end
# 0.13.0.  A library has no bin/, and its header is read from lib/ instead.
it "reads a library header from lib/" do
  library_revision(0, script('0.0.0', PLAIN_METHOD))
  library_revision(1, script('0.1.0', PLAIN_METHOD + MODIFIER_METHOD, changes: "# Changes since 0.0:\n# 1. + guarded(), for the empty case.\n"))
  run_changelogger
  _(changelog(1)).must_include '+ guarded(), for the empty case.'
end

# Where the library is not named for the revisions root there is nothing to guess
# from, and the switch is how it is said.
it "reads the header named by --header-file" do
  library_revision(0, script('0.0.0', PLAIN_METHOD), name: 'Otherwise')
  library_revision(1, script('0.1.0', PLAIN_METHOD, changes: "# Changes since 0.0:\n# 1. ~ named outright.\n"), name: 'Otherwise')
  run_changelogger('--header-file', 'lib/Otherwise.rb')
  _(changelog(1)).must_include '~ named outright.'
end

# bin/ is looked to first, a program being what changelogger was written for.
it "prefers bin/ where a project holds both" do
  revision(0, script('0.0.0', PLAIN_METHOD))
  revision(1, script('0.1.0', PLAIN_METHOD, changes: "# Changes since 0.0:\n# 1. ~ from bin.\n"))
  library_revision(1, script('0.1.0', PLAIN_METHOD, changes: "# Changes since 0.0:\n# 1. ~ from lib.\n"))
  run_changelogger
  _(changelog(1)).must_include '~ from bin.'
  _(changelog(1)).wont_include '~ from lib.'
end

# A section header carrying text after its colon ends the Changes section, which
# 0.12.1 fixed and nothing had covered.
it "ends the Changes section at a section header with text after it" do
  revision(0, script('0.0.0', PLAIN_METHOD))
  revision(1, script('0.1.0', PLAIN_METHOD, changes: "# Changes since 0.0:\n# 1. ~ the only item.\n\n# History: this paragraph is not a change.\n"))
  run_changelogger
  _(changelog(1)).must_include '~ the only item.'
  _(changelog(1)).wont_include 'this paragraph is not a change.'
end

end
