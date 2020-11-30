
## cias-api


## METADATA

* Project name: CIAS 3.0 (Computerized Intervention Authoring System);
* Owner: [Wayne State University](https://wayne.edu/);
* License: It is a property of [Wayne State University](https://wayne.edu/). All rights reserved.


## DOCUMENTATION

#### V1
* Is exposed without logging in the path `/v1/docs`;
* Technical details described in: `docs/v1/README.md`.


## DECISIONS

#### CORE LOGIC

1. Intervention is an object created to grouping sessions;
1. Session is the core object. It acts as metadata in the process of harvesting data;
1. Questions are data for session. Therefore session has got many questions through question groups;
1. The particular question contains static fields and one dynamic data field;
1. For every question, we create many answers which carry the same type and logic as a question for which they are belonged to.


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
    * API: JSON serialized by [Oj](https://github.com/ohler55/oj) in custom classes.
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
  * Static code analyzer and formatter (linter): Rubocop.


## DEVELOPMENT

### Spellchecker for RoR developers (or anyone who plan to commit)

One of the checks, starting by overcommit on pre-commit hook (at least right now) is a spellchecker.
Our spellchecker based on tool `hunspell`
* Installation on Mac: `$ brew install hspell`
* How-to check `PATH` where `hunspell` looking for dictionaries: `$ hunspell -D`
* Dictionaries can be found here: `docs/dictionaries/spell.tar.bz2`. Unpack and put
them to one of `PATH` folders. For example `/Library/Spelling/`

At the end it should looks like:
```
$ hunspell -D
...
AVAILABLE DICTIONARIES (path is not mandatory for -d option):
/Library/Spelling/en_GB
/Library/Spelling/en_US
```

### LAUNCH

* `$ git clone git@github.com:htdevelopers/cias-api.git`
* `$ cd cias-api`
* `$ cp .env.template .env`
* Retrieve and save credentials file in order to use:
  * Google Cloud Platform: `./cias-api-50c1a8455413.json`.
* `$ docker-compose up --build`
* `$ docker-compose exec api bundle exec rails db:reset`
* `$ docker-compose exec api bundle exec rails db:environment:set RAILS_ENV=development`
* If you would like to seed your database by:
  * Role based users: `$ docker-compose exec api bundle exec rails db:seed`
  * Fake data: `$ docker-compose exec api bundle exec rails db:seed:fake`
  * Production data: set `postgres` protocol and `$ pgsync --defer-constraints-v2`
* Open web browser and type: `localhost:3000/`


### HELPERS

* `localhost:3000/v1/docs`
* `localhost:3000/rails/browse_emails`
* `localhost:3000/rails/info/properties`
* `localhost:3000/rails/info/routes`
* `localhost:3000/rails/workers`

You can inspect the database. We're providing additional containers. Just execute:
* `$ docker-compose -f docker-compose.yml -f docker-compose.analytics.yml up --build`
