# CIAS

## METADATA
* Project name: CIAS 3.0 (Computerized Intervention Authoring  System);
* Owner: [Wayne university](https://wayne.edu/);
* License: It is a property of [example.com](http://example.com). All rights reserved.

## DECISIONS 
* placeholder
 
#### CORE LOGIC

## TECHNICAL STACK

#### API

* Ruby programming language:
  * OOP, SOLID, DI, design patterns.
* Ruby on Rails (RoR) web-application framework:
  * MVC, DRY, conventions over configurations.
* MVC:
  * Model:
    * ORM: ActiveRecord;
    * Databases:
      * RDBMS: PostgreSQL. Store for all data;
      * In-memory: Redis. Store for background worker, cache. 
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

#### FRONTEND

* placeholder

## DEPLOYMENT ENVIRONMENT

* backend:
  * environments:
    * staging: ; 
    * production: .
  * external:
    * [database visualisation] placeholder;
    * [logs] placeholder;
    * [mail] placeholder;
    * [search engine] placeholder;
    * [security] placeholder;
    * [server] placeholder;
    * [storage] placeholder;
* frontend:
  * placeholder.
 
## LAUNCH

#### API
* `git clone git@github.com:htdevelopers/cias-api.git`
* `cd cias-api`
* `docker-compose up`
* Open your favourite web browser, type: `localhost:3000`
