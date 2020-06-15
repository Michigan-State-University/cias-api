FROM ruby:2.7.1
ENV RUBYOPT="--jit"
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev && apt-get clean autoclean && apt-get autoremove -y && rm -rf /var/lib/apt /var/lib/dpkg /var/lib/cache /var/lib/log
RUN mkdir /api
WORKDIR /api
COPY Gemfile /api/Gemfile
COPY Gemfile.lock /api/Gemfile.lock
RUN gem install rake && gem install bundler -v "2.1.4" && bundle install -j4
COPY . /api
