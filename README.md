## cias-api

## METADATA

Copyright (C) 2023 Michigan State University

This package is part of CIAS 3.0.

CIAS 3.0 is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

CIAS 3.0 is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with CIAS 3.0. If not,
see <https://www.gnu.org/licenses/gpl-3.0.html>.

## DEVELOPMENT

### LAUNCH

- Install `git` on server:
- `$ git clone git@github.com:htdevelopers/cias-api.git`
- `$ cd cias-api`
- `$ cp .env.template .env`
- Install `ruby 2.7.2`
- Install `PostgreSQL`
- Install `bundler`
- Create database user
- Update database.yml file with login and password of database user for development environment
- Generate `./cias-api-50c1a8455413.json` file at the project location
- `$ bundle install`
- To setup new database: `$ rails db:migrate:reset`
- If you would like to seed your database by:
  - Role based users(Notice: To not run on the production!): `$ rails db:seed`
- `$ rails s`
- Open web browser and type: `localhost:3000/`

## PRODUCTION SETUP

- Install `ruby 2.7.2`
- Install `PostgreSQL`
- Install `bundler`
- Create database user
- Set database environment variables:
  - `CIAS_DATABASE_USER` with login of database user
  - `CIAS_DATABASE_PASSWORD` with password of database user
- Set environment variables from `.env.template` file with values from heroku.

### HELPERS

- `localhost:3000/rails/browse_emails`
- `localhost:3000/rails/info/routes`
- `localhost:3000/good_job - if GOOD_JOB_WEB_INTERFACE=1`

### COMMON ISSUES

- bug with generate audio
  - error message: `objc[4918]: +[__NSCFConstantString initialize] may have been in progress in another thread when fork() was called.`
  - How to fix:
    - open `.zshrc`
    - add `export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES`
    - call in project terminal `source ~/.zshrc`


### FAKE DATA GENERATOR

#### Do not use it on production environment!

- Set environment variables
  - `GENERATOR_ENABLED` to 1
  - `CIAS_ADMIN_PASSWORD` to a password of your choice
- Go to `db/seeds/interventions/cias_seed.rb` and change constant variables values if you want more specific data to be created
- Type `rake db:seed:interventions` command in server console


### BENCHMARK

- To run all implemented benchmarks enter `bundle exec rspec spec/benchmarks/*/*.rb` in server console
- To run specific benchmark replace asterisk symbols with a file from `spec/benchmarks` location. For example `spec/benchmarks/interventions/intervention_index.rb`
