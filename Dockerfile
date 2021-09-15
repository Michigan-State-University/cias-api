FROM ruby:2.7.2
ENV RUBYOPT="--jit"
RUN apt-get update -qq && apt-get install -y build-essential libpq-dev libjemalloc2 && apt-get clean autoclean && apt-get autoremove -y && rm -rf /var/lib/apt /var/lib/dpkg /var/lib/cache /var/lib/log
ENV LD_PRELOAD=/usr/lib/x86_64-linux-gnu/libjemalloc.so.2
RUN mkdir /api
WORKDIR /api
COPY Gemfile /api/Gemfile
COPY Gemfile.lock /api/Gemfile.lock
RUN gem install rake && gem install bundler -v "2.1.4" && bundle install -j4
COPY . /api
# Configure the main process to run when running the image
ADD startup.sh /
RUN chmod +x /startup.sh
CMD ["/startup.sh"]
