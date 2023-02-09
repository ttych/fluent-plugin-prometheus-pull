# frozen_string_literal: true

# require 'bundler'
# Bundler::GemHelper.install_tasks

require 'bundler/gem_tasks'
require 'rake/testtask'
require 'bump/tasks'
require 'rubocop/rake_task'

RuboCop::RakeTask.new

Rake::TestTask.new(:test) do |t|
  t.libs.push('lib', 'test')
  t.test_files = FileList['test/**/test_*.rb']
  t.verbose = true
  t.warning = true
end

task default: %i[test rubocop]
