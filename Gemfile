# frozen_string_literal: true

source "https://rubygems.org"

git_source(:github) {|repo_name| "https://github.com/#{repo_name}" }

gem "nokogiri"

group :test do
  gem 'rspec'
  gem 'rspec_junit_formatter'
  gem 'simplecov', require: false
end

group :development, :test do
  gem 'byebug'
  gem 'profile'
  gem 'rubocop', '~> 1.31'
  gem 'rubocop-rspec'
end
