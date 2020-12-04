Changelog
=========


v0.2.0 (04.12.2020)
------------
- Fix version of application in helm chart, add changes to CHANGELOG. [Jerzy Sładkowski]
- Fix application logic. [Jerzy Sładkowski]

  * for each question we should have only one answer from one user
  * add index and unique constraint for pair question_id and user_id in table answers
- Fixed readme to be in line with renaming backend entities. [Jerzy
  Sładkowski]
- Add database schemas with refactoring proposals. [Jerzy Sładkowski]
- Remove unused 'friendly slugs' [Jerzy Sładkowski]
- Rename problem to intervention. [Jerzy Sładkowski]
- Rename interventions to sessions. [Jerzy Sładkowski]
- Remove addresses completely. [Jerzy Sładkowski]
- Fix rubocop issues. [Michał Śnieć]
- Add 'exact_date' scheduling option logic. [Jerzy Sładkowski]
- Add config gem. [Jerzy Sładkowski]
- Add workaround for letter_opener_web, to fix clear functionality.
  [Jerzy Sładkowski]
- Fix code styling. [Jerzy Sładkowski]

  * update db/schema.rb to standard version for Rails6
  * add db/schema.rb as an exception for rubocop
  * fix most code styling problems according to rubocop
  * switch off rubocop from overcommit
- Disable not needed extensions. [Michał Śnieć]
- Refactor migration to not use active record method. [Michał Śnieć]

  Fix rubocop issue
- Fix pull requst template. [Michał Śnieć]
- Fix Heroku deployment. [Jerzy Sładkowski]
- Fix questions move tests to work consistantly. [Michał Śnieć]
- Fix intervention clone and set correct position. [Michał Śnieć]

  Change method name

  Add tests

  Split tests to diffrent test cases
- V0.1.2. [Michał Śnieć]
- Update chart version up to 0.1.2. [Michał Śnieć]
- Fix wrong queue prefix on production (#102) [Michał Śnieć, msniec]

v0.0.0 (29.04.2020) - v0.1.1 (17.11.2020)
------------
- Add versions discretization, based on tags [Jerzy Sładkowski]

  * fix app version in module, first version 0.1.1;
  * fix version of app in helm chart;
  * add changelog.
- Fix development gems and overcommit [Jerzy Sładkowski]

  * added 'bundler-audit' to check vulnerabilities of used gems;
  * added 'bump' gem to provide release versions discretization;
  * added 'license_finder' gem to check license of every used gem;
  * added 'simplecov' gem and start helpers to check test coverage;
  * replaced 'en_GB' language in spelling check with 'en_US';
  * added documentation for developers about hunspell and dictionaries.
- Fix bug CIAS30-658. [Jerzy Sładkowski]
- Fix bug CIAS30-655, remove Brakeman from pre-commit hook. [Jerzy
  Sładkowski]
- Question::Finish comes to play. [Michał Pawlak]
- Feature to get a production database to the development environment.
  [Michał Pawlak]
- Intervention, QuiestionGroup, Question changing position. Move
  Question. [piotrekpasciak]
- EIAT screen grouping. [piotrekpasciak]
- Permit destroy user_interventions with submitted_at equal nil. [Michał
  Pawlak]
- Schedule for interventions. UserIntervention comes to play. More
  below. [Michał Pawlak]

  * Provide three options of scheduling for interventions;
    * The logic for scheduling is handled by Intervention::Schedule class;
    * Provide a many-to-many association between users and interventions;
    * Set by default role participant for all users;
    * Provide Interventions::Users controller which handle the logic
    for listing, adding, removing users (with an invite or not) accordingly
    to reached out an endpoint;
    * Provide InterventionInvitation index, create, destroy endpoints and
    model to handle just an information about add an email to inter-
    vention and possible to send an email through.
- Improve cache key for users. [Michał Pawlak]
- Proper message on deactivated account trying to login in.
  [piotrekpasciak]
- CIAS-617 Make password easier. [piotrekpasciak]
- Size of list of users before pagination. [Michał Pawlak]
- Use smaller core containers images. [Michał Pawlak]
- Users#index contains collection size. [Michał Pawlak]
- Extend Problem JSON by user data. [Michał Pawlak]
- Question settings by default have a title set to true. [Michał Pawlak]
- CIAS-594 Remove invited user. [piotrekpasciak]
- Set the default participant role after registration. [Michał Pawlak]
- CIAS-544 New question types names. [Michał Pawlak]
- Remove title from Question settings. [Michał Pawlak]
- CIAS-483 Provide invitable functionality to researcher.
  [piotrekpasciak]
- CIAS-304 Invite researcher. [piotrekpasciak]
- CIAS-521 Promote better serializer - update. [piotrekpasciak]
- User list filter on activated or not. [Michał Pawlak]
- Base implementation of invitable module. [Michał Pawlak]
- CIAS-521 Add JSON serializer based on pure classes. [piotrekpasciak]
- Problem status restore to draft after clone. [Michał Pawlak]
- Permit time_zone during account registration. [Michał Pawlak]
- During the cloning session, the entire formula is cleaned. [Michał
  Pawlak]
- Question narrator block contains ReflectionFormula block. More below.
  [Michał Pawlak]

  * Formula will be calculated in order to provide some specific
    text and audio response based on user answer.
- CIAS-418 Add filters for users list (#68) [hubert-salamaga]

  * Add pagy gem to Gemfile
  * Add a possibility to paginate Users#index
  * Add filter for name and email to User#detailed_search
- CIAS-382 Prepare endpoint to send emails with link to session (#64)
  [Michał Pawlak, hubert-salamaga]

  * Add emails field to interventions table
  * Add endpoints to manage invitations
  * Allow making requests as a guest
  * Remove allow_guests field from Intervention
  * Remove status field from Intervention
  * Improve access to Problem for participants
  * Reorganize abilities
  * Change emails to use text instead of string
- Unify time zones naming. [Michał Pawlak]
- CIAS-408 Give endpoints for resetting password (#67) [Michał Pawlak,
  hubert-salamaga]

  * Return status ok instead of a user object after successfully sending reset password instruction
  * Prevent sending only paths in emails
  * Override render_not_found_error method in PasswordsController
  * DRY among AuthControllers
- ErrorBeacon refinement. [Michał Pawlak]
- Return next question when formula match nothing. [Michał Pawlak]
- Inject errors monitoring service on production env. [Michał Pawlak]
- CSV answers reports handle by Active Storage. [Michał Pawlak]
- CIAS-391 Add endpoints for upload and remove avatar (#59) [Michał
  Pawlak, hubert-salamaga]

  * Add endpoint to upload and remove avatars
  * Require sending current_password to updating email or password
  * Rename scope in routes
  * Update app.json for review apps purposes
  * Remove unnecessary validations
  * Override Devise's Controllers to stick convention of resource/errors rendering
  * Metaprogramming for authentication through Devise
  * Add location metadata for class_eval
  * Fix problem with the base ability
- Intervention handles schedule logic. [Michał Pawlak]
- Appropriate response after creating an answer. More below. [Michał
  Pawlak]

  * Apply branching logic between questions as
    a result of formula and patterns;
    * Apply target value with the calculated result for it
    to Question::Feedback;
    * Return JSON with data null when then the question was
    the last in intervention scope.
- Add Question::Feedback complex logic. More below. [Michał Pawlak]

  * New blocks for Narrator: Feedback,
    ReflectionFormula;
    * New JSON schema for Question::Feedback;
    * Only researcher can have many answers for
    particular question;
    * Inject logic to return appropriate resopnse
    after create answer;
    * Will not include Question::Feedback in CSV
    report.
- Extend User.phone attr. [Michał Pawlak]
- Extend the ability to manage user account. [Michał Pawlak]
- Intervention with formula attr. [Michał Pawlak]
- Manage problem permissions (#52) [htd-mpawlak]

  * helpers
  * Make #index and #create from problems/
    users_controller usable;
  * Update read privileges for participant;
    REST UserProblem with Problem and Intervention ID;
  * Remove unnecessary intervention_id from UserProblem;
  * Add endpoint to deleting a user from a problem;
  * Fix problem with specs;
  * Include app.json with configurations for review apps;
  * Return a list of created associations after
    problems/users#create;
- Reorder interventions. [Michał Pawlak]
- Add cfg for service email provdier: SendGrid. [Michał Pawlak]
- Add pause block. [Michał Śnieć]

  Add missing tests

  Fix failng test
- Add Adress to user. [Michał Pawlak]
- Additional data about users to CSV report. [Michał Pawlak]
- Scope to v1 API sources and API docs. [Michał Pawlak]
- Intervention no longer belongs to the user. [Michał Pawlak]
- Feature to make a clone: Problem, Intervention, Question. [Michał
  Pawlak]
- Branching between interventions. [Michał Pawlak]
- CIAS-322 Remove speech blocks when voice is disabled (#47) [hubert-
  salamaga]

  * Clean up blocks if any setting for the question has been disabled
- Harvesting answers and create CSV from them. [Michał Pawlak]
- CIAS-327 Handle ReadQuestion block (#45) [hubert-salamaga]

  * Create Audio model
  * Reorganize blocks
  * Move TextToSpeech class with subclasses to other directory
  * Support ReadQuestion block
  * Remove from_question & update specs
  * Adjust blobs' logic to Audio objects
  * Update specs to be more variety
  * Remove speech_source
  * Clean up code
- [CIAS-326] Researcher should be able to add answers (#44) [hubert-
  salamaga]

  * Update seeds to create sample users
  * Make sure that researcher can create answers
- [CIAS-273] Add narrator reflections (#43) [hubert-salamaga]

  * Separate handle Speech block to the class
  * Create a class to handle Reflection blocks for Narrator
  * Refactor classes; DRY
- [CIAS-289] Adjust backend to group interventions (#41) [hubert-
  salamaga]

  * Create problems table with needed dependentions
  * Create Problem model and update user abilities
  * Add ProblemsController with needed endpoints
  * Add status to Problem model and allow to change it
  * Update specs & Make RuboCop happy
  * Update docs
  * Add problem_id to InterventionSerializer
- [CIAS-280] text-to-speech (TTS) readjust logic (#40) [Hubert Salamaga,
  htd-mpawlak]

  * Readjust logic of question's narrator
  * Fix problem with adding blocks and text-to-speech
  * Update Procfile
  * Pass google credentials via ENVs
  * Update specs & Make RuboCop happy
- [CIAS-285] Add `show_number` to #assign_default_values in
  Question::AnalogueScale (#42) [hubert-salamaga]
- Text-to-speech (TTS) implementation. [Michał Pawlak]
- In question access to intervention by ID or slug. [Michał Pawlak]
- URLs on the production environment generate correctly. [Michał Pawlak]
- Default values for Intervention and Question. Read below. [Michał
  Pawlak]

  * To Intervention and Question attributes, we provide
    default values using Active Record attributes API.
- Production config for Active Storage on Amazon S3. [Michał Pawlak]
- Question settings fix assignment custom values. [Michał Pawlak]
- Intervention: guest access, status, slug. More below. [Michał Pawlak]

  * Provide guest user if the current user does not exist;
    * Expose inter. for guests when URL contains a query string;
    * Handle the current status of intervention;
    * Can update intervention status;
    * Expose slug from a name on intervention;
    * Update abilities.
- Browse emails on development env. [Michał Pawlak]
- Clone question for an image if exists. [Michał Pawlak]
- Update roles in the ability. [Michał Pawlak]
- Endpoint for users with index, show, update, destroy. [Michał Pawlak]
- Extend skipping logic in Question. [Michał Pawlak]
- Update Intervention narrator set., propagate to questions. [Michał
  Pawlak]
- Add an answer required setting to Question. [Michał Pawlak]
- Reorder questions. [Michał Pawlak]
- Add default settings to Question. [Michał Pawlak]
- Assign default values for Intervention settings. [Michał Pawlak]
- New JSON structure for body in Question. [Michał Pawlak]
- User registration functionality improve. [Michał Pawlak]
- Endpoint for updating interventions. [Michał Pawlak]
- Endpoint for cloning questions. [Michał Pawlak]
- Endpoint for delete questions. [Michał Pawlak]
- Evaluate variables in answers to provide order logic for Question.
  [Michał Pawlak]
- Add narrator attribute to Question (plus provide schema, assign
  default values) [Michał Pawlak]
- Invalidate cache, inverse_of for relations. More below. [Michał
  Pawlak]

  * Provide a private method to invalidate
    cache for certain actions in controllers;
    * For memory optimization in order to prevent
    exception uninitialized constant because highly
    used STI, manually add inverse_of: Intervention,
    Question, Answer;
    * Rescue from ActiveRecord::RecordNotSaved
    implemented in exception handler;
    * Change assign default attributes only when
    create object.
- Intervention and Question settings attribute. More below. [Michał
  Pawlak]

  * They keep hash settings without a predefined schema;
    * Option of default assign settings on initialize;
    * Fix Question Grid in seeds/fake;
    * Avoid N+1 for Question and Image;
    * Set default JSON parser to Oj.
- Delegate to nested controller Question image. More below. [Michał
  Pawlak]

  * QuestionSerializer on image_url return full path URL;
    * Documentation and tests for Question::Images controller;
    * Log::UserRequest omit saving files from Question::Images
    controller.
- JSON schema to Question. Active Storage. More below. [Michał Pawlak]

  * Question STI mechanism validates formula and body
    JSON attributes accordingly to subclass;
    * Add ActiveStorage engine.
- Basic implementation of screen rearranging. More below. [Michał
  Pawlak]

  * Add to Question attributes to keep information
    about:
      - order of question while creating them;
      - formula and patterns to store and process variables.
    * Implement arithmetic and logic parser;
    * Remove previously implemented self joins
    in Question because we need more complex
    logic than simple relation to itself.
- Remove logic duplication in the architecture of Question, Answer.
  [Michał Pawlak]
- Database data definition - improve security. More below. [Michał
  Pawlak]

  * Set to use UUID for PK, FK in every table;
    * Relation are using UUID with Rails convention;
    * Appropriate indexes;
    * Add to Docker, services which provide data visualisation
    and data definition language inspect.
- Validations for elements size in the body field. More below. [Michał
  Pawlak]

  * BodyInterface extended to handle
    many types of validations of body field;
    * We add validations which checking  if
    contains exactly:
      - one element;
      - at least one element.
    * Validation for body attribute, we can share
    between Question and Answer subclasses;
    * If validation fails, it raises an exception with
    a message.
- Handle answer logic. Read more below. [Michał Pawlak]

  * Design answer data model, associations,
    validations, serializer, expose actions;
    * API documentation for Answer resource;
    * Dynamic mechanism for the body field
    in Answer, Question to extend the functionality
    of subclass and protect that;
    * Rename administrator role to admin;
    * Auth user by username instead of email;
    * Optimize database data definition;
    * Tests.
- HIPAA appliance - for a current user we log - more below. [Michał
  Pawlak]

  * Current user;
    * Controller and action;
    * Query string;
    * Params;
    * User agent;
    * Additional: set 15 min. timeout for user session.
- Create Intervention and Question data model and routing scope. More
  below. [Michał Pawlak]

  * Intervention has got many questions. Question belongs to
      intervention;
    * Mechanism of single-table inheritance taking care of different logic
      for intervention and questions;
    * Particular question data is stored in JSON field. Therefore, we avoid
      polluting database unnecessarily;
    * For every question we provide a class to manipulate data accordingly
      to Object-Oriented Programming paradigms;
    * We apply the polymorphic approach to have coherent
      and extensible logic for questions;
    * Update API documentation, add JSON serializer and tests.
- Update auth. config., API docs read more below. [Michał Pawlak]

  * API documentation lives in docs/;
    * Documentation is produced by slate gem. For more info
      information, checkout out docs/README.md;
    * Add guard to build automatically docs on development.
- Update continuous integration configuration. [Michał Pawlak]
- Fix production config. [Michał Pawlak]
- API documentation in OpenAPI format. [Michał Pawlak]
- Add admin user. [Michał Pawlak]
- Implement authentication and authorization. Read more below. [Michał
  Pawlak]

  * Authentication through Devise on User model extended by
      devise_token_auth;
    * Switch to Argon2 encryptor which offers additional security
      than BCrypt;
    * Authorization scope through CanCanCan;
    * User roles the same which exist in CIAS 2.0 (2020-05-04);
    * Update Rack::CORS in order work app properly as API;
    * RSpec for User.
- Update Puma configuration, typo in config.cache_store. [Michał Pawlak]
- README typo. [Michał Pawlak]
- Merge pull request #1 from htdevelopers/develop. [mpawlak-htd]

  CIAS-5 project setup & kickoff
- Overcommit configuration. Read more below. [Michał Pawlak]

  * Gems responsible for productivity, unification,
     standards, security delegated to Overcommit.
- Docker for development, Heroku config, new gems. Read more below.
  [Michał Pawlak]

  * Simplify Docker config for development;
    * Heroku dynos run through Procfile;
    * Gems for improving development, security and
      optimize database queries.
- Add .circleci/config.yml. [Michał Pawlak]
- Containerize self. [Michał Pawlak]
- Config for cache and background worker. [Michał Pawlak]
- Config: ENVs, database, web server. [Michał Pawlak]
- Install RSpec. [Michał Pawlak]
- Add config for editors, update .gitignore. [Michał Pawlak]
- Add and execute static code analyzer. [Michał Pawlak]
- Add basics gems. [Michał Pawlak]
- Add README. [Michał Pawlak]
- Initial. [Michał Pawlak]
