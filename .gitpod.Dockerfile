FROM gitpod/workspace-full:latest

USER gitpod

RUN npm i -g @antora/cli
RUN npm i -g gulp

