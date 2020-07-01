## cias-api


## METADATA
* Project name: CIAS 3.0 (Computerized Intervention Authoring System);
* Owner: [Wayne State University](https://wayne.edu/);
* Documentation:
  * Is exposed without logging in the path `/docs`;
  * Technical details described in: `docs/README.md`.
* License: It is a property of [Wayne State University](https://wayne.edu/). All rights reserved.


## DECISIONS

#### CORE LOGIC

1. Intervention is the core object. It acts as metadata in the process of harvesting data;
1. Questions are data for intervention. Therefore intervention has got many questions;
1. The particular question contains a static fields and one dynamic data field;
1. For every question, we create many answers which carry the same type and logic as question for which they are belonged to.


#### PATTERNS

1. To store dynamic data in Question and Answer, we are using JSON data-interchange format ([RFC 7158](https://tools.ietf.org/html/rfc7158), [RFC 7159](https://tools.ietf.org/html/rfc7159), [RFC 8259](https://tools.ietf.org/html/rfc8259)).


## TECHNICAL STACK

* Ruby programming language:
  * OOP, SOLID, DI, design patterns.
* Ruby on Rails (RoR) web-application framework:
  * MVC, DRY, convention over configuration.
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
* API documentation: Slate;
* Code quaility:
  * Static code analyzer and formatter: Rubocop.


## DEVELOPMENT

### LAUNCH

* `$ git clone git@github.com:htdevelopers/cias-api.git`
* `$ cd cias-api`
* `$ cp .env.template .env`
* `$ docker-compose up --build`
* `$ docker-compose exec api bundle exec rails db:environment:set RAILS_ENV=development`
* `$ docker-compose exec api bundle exec rails db:reset db:seed:fake`
* Open web browser and type: `localhost:3000/`


### HELPERS

* `localhost:3000/docs`
* `localhost:3000/rails/browse_emails`
* `localhost:3000/rails/info/properties`
* `localhost:3000/rails/info/routes`
* `localhost:3000/rails/workers`
