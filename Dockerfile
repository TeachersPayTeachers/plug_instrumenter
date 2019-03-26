FROM bitwalker/alpine-elixir:1.6.6

RUN mix local.hex --force
RUN mix local.rebar --force

RUN mkdir -p /api
COPY mix.exs /api
COPY mix.lock /api
WORKDIR /api
RUN mix deps.get

COPY . .

CMD ["mix", "test"]
