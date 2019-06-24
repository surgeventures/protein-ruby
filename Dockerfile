FROM ruby:2.4.4-slim

WORKDIR /protein

RUN apt-get update -qq && apt-get install -y netcat

COPY Gemfile protein.gemspec ./
RUN mkdir -p ./lib/protein/
COPY lib/protein/version.rb ./lib/protein/

RUN bundle install

COPY . ./
