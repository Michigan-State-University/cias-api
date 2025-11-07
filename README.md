Copyright (C) 2023 Michigan State University

This package is part of CIAS 3.0.

CIAS 3.0 is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as
published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version.

CIAS 3.0 is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty
of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

You should have received a copy of the GNU General Public License along with CIAS 3.0. If not,
see <https://www.gnu.org/licenses/gpl-3.0.html>.

# [CIAS 3.0](https://www.cias.app/)

CIAS 3.0 platform source code is divided into two separate repositories:
- [Frontend package](https://github.com/Michigan-State-University/cias-web#readme)
- [Backend package](https://github.com/Michigan-State-University/cias-api#readme) - <b>current</b>

## Digital Behavioral Health Interventions Made Easy

CIAS stands for Computerized Intervention Authoring System. CIAS gives you the ability to create and manage
multi-session interventions without writing a single line of code. With this robust platform, you can develop and
deliver interventions, collect data, and collaborate with colleagues all in one place.

## User-Friendly Features

The CIAS platform has a variety of features to support a broad range of interventions and approaches, including:

- Variety of **question types** to choose from
- An **animated narrator** to act as a guide
- The ability to speak out loud using high-quality text to speech
- Optional quick exit feature for participant safety
- Automatic **translation** into over 100 languages
- **Tailored reports** for participants and clinicians
- Custom and tailored **SMS messaging**
- **Branching** and **Randomization**
- Synchronous natural language reflections and summaries
- **Scheduled** session sending
- Custom **charts** for data visualisation
- HIPAA and WCAG 2.0 compliant
- Timeline Followback Method Assessment (**TLFB**)
- Secure **Live chat** connecting participants with a peer, CHW, BHC, etc.
- Integrations with 3rd party systems:
  - **CAT-MH<sup>TM</sup>**
  - Epic on FIHR (forthcoming)

For more information about CIAS 3.0 features please see https://www.cias.app.

## Full Version Available for Free*

Our goal is for cost to never be a barrier. This code is available to anyone at no cost. Further, Michigan State University currently provides an instance of CIAS 3.0 that is available at low or no cost for non-commercial use by researchers at universities or non-profit research institutions. Immediate access is always provided without charge and without paperwork, and CIAS remains free for unfunded projects. (edited) 

*A small annual fee will be requested for funded projects.

### For more information, or to request access to the MSU instance of CIAS, please see https://www.cias.app/ or contact [CIAS@msu.edu](cias@msu.edu)

## DEVELOPMENT

### LAUNCH

- Install `git` on server:
- `$ git clone git@github.com:Michigan-State-University/cias-api.git`
- `$ cd cias-api`
- `$ cp .env.template .env`
- Install `ruby 3.1.7`
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

- Install `ruby 3.1.7`
- Install `PostgreSQL`
- Install `bundler`
- Create database user
- Set database environment variables:
  - `CIAS_DATABASE_USER` with login of database user
  - `CIAS_DATABASE_PASSWORD` with password of database user
  - `DATABASE_URL` with url to the specific database
- Set environment variables from `.env.template` file with correct values.

### HELPERS (development environment)

- Interface for browsing sent emails:  `localhost:3000/rails/browse_emails`
- All available paths: `localhost:3000/rails/info/routes`
- Web UI for sidekiq: `localhost:3000/rails/workers`
- to reset database run `./db_reset.sh` in the console


### File structure 

#### /app
It organizes this application components. It's got subdirectories that hold the channels, exceptions, controllers, finders, jobs, mailers, models, queries, serializers, services and views.

#### /config
This directory contains configuration code that this application need, among other things, database configuration, Rails environment structure, and routing of incoming web requests (routes.rb).

#### /db
This application has model objects that access relational database tables. You can manage the relational database with scripts you create and place in this directory.

#### /spec
This is a place in this app when you can find all automatic tests. Here, too, there is a division into directories depending on what is being tested. Tests for services you can find in `spec/services`, for controllers in `spec/requests` and soo on. 

#### /lib/tasks
This is the place when you can find all our custom rake tasks. If you want to see all list run in the console `rake -T`.

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
