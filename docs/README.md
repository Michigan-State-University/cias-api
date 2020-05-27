## docs/

## METADATA

* Documentatation is:
  * Provided by gem:
      * [slate](https://github.com/slatedocs/slate) (version 2.4.0).
  * Exposed without logging in the path `localhost:3000/docs`.
* License:
  * Apache;
  * Version 2.0, January 2004.

## BUILD

If you have got `.env` file in the root of cias-api, go to point 3, if not, start from the beginning:
1. `$ cd cias-api`
1. `$ cp .env.template .env`
1. `$ cd cias-api/docs`
1. `$ ln -s -r ../.env ./.env`
1. `$ bundle install`
1. `$ rails docs:build`
