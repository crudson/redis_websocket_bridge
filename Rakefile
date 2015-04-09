require 'bundler'

Bundler::GemHelper.install_tasks

require 'rake'
require 'rake/testtask'

Rake::TestTask.new do |t|
  t.test_files = Dir.glob('test/*_test.rb')
end
