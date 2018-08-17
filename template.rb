# Need to keep track of devise configuratio
@devise_models = []

# Add the current directory to the path Thor uses
# to look up files
def source_paths
  Array(super) +
    [File.expand_path(File.dirname(__FILE__))]
end

# ---------------------- CONFIGURATION METHODS ----------------------

def config_gems
  # Remove unwanted gems
  gsub_file 'Gemfile', /.*jbuilder.*/, ''
  gsub_file 'Gemfile', /.*pg.*/, ''
  gsub_file 'Gemfile', /.*sqlite.*/, ''

  # Add always wanted gams
  gem 'jquery-rails'
  gem 'font-awesome-sass', '~> 5.0.13'
  gem 'friendly_id'
  gem 'simple_form', '~> 4.0.0'
  gem 'slim-rails', '~> 3.1.3'
  gem 'enumerize', '~> 2.2.2'
  gem 'awesome_print'

  gem 'devise'
  gem 'devise-i18n'
  gem 'pundit'
  gem 'omniauth-google-oauth2', '~> 0.4.1'

  gem 'rubocop', '~> 0.55.0', require: false

  gem 'kaminari', '~> 1.1.1'

  gem 'aws-ses', '~> 0.6.0', require: 'aws/ses'

  gem 'faker', git: 'https://github.com/stympy/faker.git', branch: 'master'
  gem "pg"

  gem_group :production do
    gem 'exception_notification'
  end

  gem_group :development, :test do
    gem 'dotenv-rails', '~> 2.1', require: 'dotenv/rails-now'

    # Test
    gem 'factory_bot_rails', '~> 4.8.2'
    gem 'rspec-rails', '~> 3.7.2'
    gem 'shoulda', '~> 3.5.0'
    gem 'simplecov', '~> 0.16.1', require: false

    # Guard and guard plugins
    gem 'guard', '~> 2.14.2'
    gem 'guard-rubocop' # Rubocop
    gem 'guard-rspec', '~> 4.7.3' # RSpec
    gem 'guard-brakeman' # Automatically run tests
  end
end

def config_stylesheet_schema
  # Remove css files and add scss templates
  inside 'app/assets/stylesheets' do
    # Remove application.css file
    remove_file 'application.css'

    # Create application.scss file
    create_file 'application.scss' do <<-EOF
// Awesome Icons
@import "font-awesome-sprockets";
@import "font-awesome";

// Project Pallete
@import "colors";

// CSS variables
@import "variables";

// Custom Stylesheets
@import "index";
@import "components/index";
    EOF
    end

    # Create index and variables scss files
    run 'touch _index.scss'
    run 'touch _variables.scss'

    # Create componets folder and index scss files
    run 'mkdir components'
    run 'touch components/_index.scss'

    # Create colors scss file
    create_file '_colors.scss' do <<-EOF
$dark-orange: #A85619;
$orange: #E87722;
$light-orange: #FF9D19;
$lighter-orange: #FF913F;

$dark-purple: #4A2458;
$purple: #7F3E98;
$light-purple: #AE3FAF;
$lighter-purple: #C574E4;

$dark-yellow: #B9A639;
$yellow: #F9DF4D;
$light-yellow: #E2DA3B;
$lighter-yellow: #FFE868;

$dark-blue: #2392B4;
$blue: #30C5F4;
$light-blue: #207EDD;
$lighter-blue: #4CD4FF;

$dark-pink: #A0366F;
$pink: #E04B9B;
$light-pink: #F7464D;
$lighter-pink: #FF6FBC;

$white: #FFFFFF;

$grey: #999999;
$light-grey: #BBBBBB;

$black: #000000;
$light-black: #222222;
    EOF
    end
  end
end

def remove_turbolinks
  # Edit gemfile
  gsub_file 'Gemfile', /.*turbolinks.*/, ''

  # Edit application.js file
  gsub_file 'app/assets/javascripts/application.js', /.*turbolinks.*/, ''

  # Remove turbolinks from layouts
  gsub_file 'app/views/layouts/application.html.erb',
            /, 'data-turbolinks-track': 'reload'/, ''
end

def config_bootstrap
  # Add bootstrap and jquery dependencies
  insert_into_file 'app/assets/javascripts/application.js', before: "//= require_tree ." do <<-RUBY
//= require jquery3
//= require jquery_ujs
//= require popper
//= require bootstrap
  RUBY
  end

  insert_into_file 'app/assets/stylesheets/application.scss', before: "// Awesome Icons" do <<-RUBY
// Bootstrap
@import "bootstrap";\n
  RUBY
  end
end

def config_simple_form
  generate 'simple_form:install --bootstrap'
end

def config_kaminari
  generate 'kaminari:views bootstrap4'
end


def config_devise_application_controller
  authenticated_models = ''

  if @devise_models.any?
    @devise_models.each do |m|
      authenticated_models += "before_action :authenticate_#{m.strip.downcase}!\n"
    end
  end

  insert_into_file 'app/controllers/application_controller.rb',
  after: 'include Pundit' do <<-RUBY
  \n
  protect_from_forgery with: :exception

  before_action :configure_permitted_parameters, if: :devise_controller?
  #{authenticated_models}
  RUBY
  end

  insert_into_file 'app/controllers/application_controller.rb',
  after: 'rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized' do <<-RUBY
  \n
  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_in, keys: %i[email password password_confirmation])
  end
  RUBY
  end
end

def config_devise_controllers
  if @devise_models.any?
    @devise_models.each do |m|
      generate "devise:controllers #{m.strip.downcase}"
    end
  end

  config_devise_application_controller
end

def create_devise_models
  models = ask("\n\tQual o nome do Model? Para mais de um, separe por vírgula.\n\tEx.: user,admin,manager\n\t")

  models.strip.split(',').each { |m| generate "devise #{m.strip.downcase}" }

  @devise_models = models.strip.split(',')

  rails_command 'db:migrate'

  config_devise_controllers if yes?("\n\tDeseja configurar os Controllers do Devise (y/n)?")
end

def config_devise
  # Update to keep track of devise configuration
  @devise_configured = true

  generate 'devise:install'

  insert_into_file 'config/environments/development.rb',
  after: 'config.file_watcher = ActiveSupport::EventedFileUpdateChecker' do <<-RUBY
  \n
  # Devise Configuration
  config.action_mailer.default_url_options = { host: 'localhost', port: 3000 }
  RUBY
  end

  create_devise_models if yes?("\nDeseja criar os Models agora (y/n)?")

  generate 'devise:views'
end

def config_pundit
  insert_into_file 'app/controllers/application_controller.rb',
  after: 'class ApplicationController < ActionController::Base' do <<-RUBY

  include Pundit

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    flash[:alert] = 'Você não possui autorização para fazer esta ação.'
    redirect_to(request.referrer || root_path)
  end
  RUBY
  end

  generate 'pundit:install'
end

def config_rubocop
  create_file '.rubocop_todo.yml' do <<-EOF
# Offense count: 2
# Configuration parameters: CountComments, ExcludedMethods.
Metrics/BlockLength:
  Max: 298

# Offense count: 2
# Configuration parameters: CountComments.
Metrics/MethodLength:
  Max: 15

# Offense count: 1
# Cop supports --auto-correct.
# Configuration parameters: AutoCorrect, EnforcedStyle.
# SupportedStyles: nested, compact
Style/ClassAndModuleChildren:
  Exclude:
    - 'test/test_helper.rb'

# Offense count: 17
Style/Documentation:
  Enabled: false

# Offense count: 2
Style/MixinUsage:
  Exclude:
    - 'bin/setup'
    - 'bin/update'

# Offense count: 159
# Configuration parameters: AllowHeredoc, AllowURI, URISchemes, IgnoreCopDirectives, IgnoredPatterns.
# URISchemes: http, https
Metrics/LineLength:
  Max: 200

Metrics/AbcSize:
  Max: 25
    EOF
  end

  create_file '.rubocop.yml' do <<-EOF
inherit_from: .rubocop_todo.yml

AllCops:
  Include:
    - app/**/*
  Exclude:
    - db/schema.rb
    - Gemfile
    - spec/**/*
    - Guardfile
    - config/**/*
    - bin/**/*
    - app/views/**/*
    - app/assets/**/*
    EOF
  end
end

def config_rspec
  generate 'rspec:install'
end

def config_simplecov
  insert_into_file 'spec/rails_helper.rb',
  before: "require 'spec_helper'" do <<-RUBY
require 'simplecov'
SimpleCov.start\n
RUBY
  end
end







# ---------------------- TEMPLATE ADD SCRIPT ----------------------

# Gemfile configuration
config_gems

# Create stylesheet files and folders
config_stylesheet_schema

# Remove turbolinks
remove_turbolinks if yes?("\nDeseja remover o turbolinks do Projeto (y/n)?")

# Configure Bootstrap
config_bootstrap

# Configure Rubocop
config_rubocop


# After Bundle actions
after_bundle do
  # Stop sprign to avoid further issues
  run 'spring stop'

  # Configure simple_form with bootstrap
  config_simple_form

  # Configure kaminari views
  config_kaminari

  # Configure Pundit
  config_pundit

  # Configure rspec
  config_rspec

  # Configure Simplecov
  config_simplecov

  # Create database
  rails_command 'db:create'

  # Configure devise, if user wishes to
  config_devise if yes?("\nDeseja que o Devise seja configurado (y/n)?")
end
