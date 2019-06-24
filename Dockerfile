FROM ruby:2.4.4-slim

WORKDIR /protein

RUN apt-get update -qq && apt-get install -y curl netcat

RUN curl -qO https://raw.githubusercontent.com/eficode/wait-for/f71f8199a0dd95953752fb5d3f76f79ced16d47d/wait-for && chmod a+x ./wait-for

COPY Gemfile protein.gemspec ./
RUN mkdir -p ./lib/protein/
COPY lib/protein/version.rb ./lib/protein/

RUN bundle install

COPY . ./
