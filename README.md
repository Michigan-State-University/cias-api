## cias-api

## METADATA
* Project name: CIAS 3.0 (Computerized Intervention Authoring  System);
* Owner: [Wayne university](https://wayne.edu/);
* License: It is a property of [Wayne university](https://wayne.edu/). All rights reserved.

## DECISIONS 
 
#### CORE LOGIC

* placeholder

## TECHNICAL STACK

* Ruby programming language:
  * OOP, SOLID, DI, design patterns.
* Ruby on Rails (RoR) web-application framework:
  * MVC, DRY, conventions over configurations.
* MVC:
  * Model:
    * ORM: ActiveRecord;
    * Databases:
      * RDBMS: PostgreSQL. Store for all data;
      * In-memory: Redis store for background worker and cache. 
  * View:
    * API: JSON serialized by: fast_jsonapi.
  * Controller:
    * Default RoR controller.
* Identity user:
  * Authentication: devise_token_auth;
  * Authorization: CanCanCan.
* Background worker: sidekiq;
* Tests:
  * RSpec;
  * Shoulda Matchers;
  * factory_bot_rails.
* Code quaility:
  * Static code analyzer and formatter: Rubocop.

## LAUNCH

* `$ git clone git@github.com:htdevelopers/cias-api.git`
* `$ cd cias-api`
* `$ docker-compose up --build`
* `$ docker-compose stop`
* `$ docker-compose exec api bundle exec rails db:setup db:migrate db:seed`
* `$ docker-compose up`
* Open web browser and type: `localhost:3002`
