
## cias-api


## METADATA

* Project name: CIAS 3.0 (Computerized Intervention Authoring System);
* Owner: [Wayne State University](https://wayne.edu/);
* License: It is a property of [Wayne State University](https://wayne.edu/). All rights reserved.


## DEVELOPMENT

### LAUNCH
* Install `git` on server:
* `$ git clone git@github.com:htdevelopers/cias-api.git`
* `$ cd cias-api`
* `$ cp .env.template .env`
* Install `ruby 2.7.2`
* Install `PostgreSQL`
* Install `bundler`
* Create database user
* Update database.yml file with login and password of database user for development environment  
* Generate `./cias-api-50c1a8455413.json` file at the project location
* `$ bundle install`
* To setup new database: `$ rails db:migrate:reset`
* If you would like to seed your database by:
  * Role based users(Notice: To not run on the production!): `$  rails db:seed`
* `$ rails s`  
* Open web browser and type: `localhost:3000/`

## PRODUCTION SETUP
* Install `ruby 2.7.2`
* Install `PostgreSQL`
* Install `bundler`
* Create database user
* Set database environment variables:
  * `CIAS_DATABASE_USER` with login of database user
  * `CIAS_DATABASE_PASSWORD` with password of database user
* Set environment variables from `.env.template` file with values from heroku.

### HELPERS

* `localhost:3000/rails/browse_emails`
* `localhost:3000/rails/info/routes`
* `localhost:3000/good_job - if GOOD_JOB_WEB_INTERFACE=1`
