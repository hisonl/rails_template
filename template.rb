# include settings
@repo_url = 'https://raw.githubusercontent.com/hisonl/rails_template/master'
@app_name = app_name
@env_name = @app_name.upcase

# clean file
run 'rm README.rdoc'

# add to Gemfile
append_file 'Gemfile', <<-CODE

# view
gem 'slim-rails'
gem 'active_link_to'
gem 'bootstrap-sass'
gem 'font-awesome-rails'

# CSS Support
# gem 'less-rails'

# form Builders
gem 'simple_form'

# turbolinks support
gem 'jquery-turbolinks'

# Pagenation
gem 'kaminari'

# HTML Parser
gem 'nokogiri'

# App Server
gem 'unicorn'

# settings
gem 'dotenv-rails'
gem 'settingslogic'

# DB
gem 'mysql2'
gem 'activerecord-mysql-unsigned'
gem 'pg'

# uploader
gem 'carrierwave'
gem 'fog'
gem 'aws-sdk'

# pagination
gem 'kaminari'

group :development, :test do
  # pry
  gem 'pry-rails'
  gem 'pry-doc'
  gem 'pry-stack_explorer'
  gem 'pry-coolline'
  gem 'pry-byebug'
  gem 'awesome_print'

  # hirb
  gem 'hirb'
  gem 'hirb-unicode'

  # rspec
  gem 'rspec-rails'
  gem 'factory_girl_rails'
  gem 'rubocop'
  gem 'better_errors'
end

group :development do
  gem 'guard'
  gem 'guard-rspec'
  gem 'guard-bundler'
  gem 'guard-rubocop'
  gem 'guard-livereload', require: false
  gem 'terminal-notifier-guard'
  gem 'html2slim'
  gem 'bullet'
end

group :test do
  gem 'faker'
  gem 'capybara'
  gem 'database_cleaner'
  gem 'launchy'
  gem 'selenium-webdriver'
  gem 'simplecov'
  gem 'webmock'
  gem 'simplecov-rcov'
  gem 'rspec-json_matcher'
end

group :production, :staging do
  # for Heroku
  gem 'rails_12factor'
end
CODE

# direnv settings
run "echo 'export PATH=,/bin:./bin:$PATH' >> .envrc; direnv allow ."

# install gems
run 'bundle install --binstubs=,/bin'

# authentication
unless no?('does not use devise and cancancan[no] ?')
  gem 'devise'
  gem 'cancancan'
  run 'bundle install'

  generate 'devise:install'
  model_name = ask("What would you like the user model to be called? [user]")
  model_name = "user" if model_name.blank?
  generate "devise", model_name

  generate 'cancan:ability'
end

# use Rspec instead of TestUnit
remove_dir 'test'

# set config/application.rb
application  do
  %q{
    # Set timezone
    config.time_zone = 'Tokyo'
    config.active_record.default_timezone = :local

    # 日本語化
    I18n.enforce_available_locales = true
    config.i18n.load_path += Dir[Rails.root.join('config', 'locales', '**', '*.{rb,yml}').to_s]
    config.i18n.default_locale = :ja

    # generatorの設定
    config.generators do |g|
      g.orm :active_record
      g.template_engine :slim
      g.test_framework  :rspec, :fixture => true
      g.fixture_replacement :factory_girl, :dir => "spec/factories"
      g.view_specs false
      g.controller_specs false
      g.routing_specs false
      g.helper_specs false
      g.request_specs false
      g.assets false
      g.helper false
    end

    # libファイルの自動読み込み
    config.autoload_paths += %W(#{config.root}/lib)
    config.autoload_paths += Dir["#{config.root}/lib/**/"]
  }
end

# For Bullet (N+1 Problem)
insert_into_file 'config/environments/development.rb',%(
  # Bulletの設定
  config.after_initialize do
    Bullet.enable = true # Bulletプラグインを有効
    Bullet.alert = true # JavaScriptでの通知
    Bullet.bullet_logger = true # log/bullet.logへの出力
    Bullet.console = true # ブラウザのコンソールログに記録
    Bullet.rails_logger = true # Railsログに出力
  end
), after: 'config.assets.debug = true'

# set Japanese locale
run 'wget https://raw.github.com/svenfuchs/rails-i18n/master/rails/locale/ja.yml -P config/locales/'

# Bootstrap/Bootswach/Font-Awesome
run 'rm -rf app/assets/stylesheets/application.css'
run 'wget https://raw.github.com/morizyun/rails4_template/master/app/assets/stylesheets/application.css.scss -P app/assets/stylesheets/'

# simple form
generate 'simple_form:install --bootstrap'

# setting logic
run 'wget https://raw.github.com/morizyun/rails4_template/master/config/application.yml -P config/'
run 'wget https://raw.github.com/morizyun/rails4_template/master/config/initializers/settings.rb -P config/initializers/'

# Kaminari config
generate 'kaminari:config'

# Database
run 'rm -rf config/database.yml'
@use_postgre = yes?('Use PostgreSQL?([yes] else MySQL)') ? true : false

if @use_postgre
  run "wget #{@repo_url}/config/postgresql/database.yml -P config/"
  run "createuser #{@app_name} -s"
else
  run "wget #{@repo_url}/config/mysql/database.yml -P config/"
end
gsub_file 'config/database.yml', /APPNAME/, @app_name
gsub_file 'config/database.yml', /ENVNAME/, @env_name

# MySQL settings
unless @use_postgre
  run "touch config/initializers/innodb_row_format.rb"
  insert_into_file 'config/initializers/innodb_row_format.rb', %(ActiveSupport.on_load :active_record do
  module ActiveRecord::ConnectionAdapters
    module SchemaStatements
      def create_table_with_innodb_row_format(table_name, options = {})
        table_options = options.merge(options: "ENGINE=InnoDB ROW_FORMAT=COMPRESSED")
        create_table_without_innodb_row_format(table_name, table_options) do |td|
          yield td if block_given?
        end
      end
      alias_method_chain :create_table, :innodb_row_format
    end
  end
  end), before: ''
end

# guard
run 'bundle exec guard init'

# Rspec/Spring/Guard
# ----------------------------------------------------------------
# Rspec
generate 'rspec:install'
run "echo '--color -f d' > .rspec"

insert_into_file 'spec/spec_helper.rb', %(require 'simplecov'
require 'simplecov-rcov'
SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter
SimpleCov.start 'rails'

require "webmock/rspec"
require "factory_girl"
require "rspec/json_matcher"
), before: '# This file was generated by the `rails generate rspec:install` command. Conventionally, all'

insert_into_file 'spec/spec_helper.rb', %(
  config.include RSpec::JsonMatcher
  config.include FactoryGirl::Syntax::Methods

  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with :truncation
  end

  config.before(:each) do
    DatabaseCleaner.start
    FactoryGirl.reload
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end
), after: 'RSpec.configure do |config|'
gsub_file 'spec/spec_helper.rb', "require 'rspec/autorun'", ''

# rake db:create db:migrate
run 'bundle exec rake RAILS_ENV=development db:create'
run 'bundle exec rake RAILS_ENV=development db:migrate'

# setting unicorn
run "touch config/unicorn.rb"
insert_into_file 'config/unicorn.rb', %(worker_processes 2
listen 3000
timeout 300
), before: ''

# .gitignore
remove_file '.gitignore'
get "#{@repo_url}/gitignore", '.gitignore'

# .pryrc
get "#{@repo_url}/pryrc", '.pryrc'

# git initalize setting
after_bundle do
  git :init
  git add: '.'
  git commit: %Q{ -m 'Initial commit' }
end
