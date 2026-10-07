# Hosting a Play together relay

Play together needs a relay: a small server that every player's copy of
Project Swiftie connects to. It hands out room codes and passes game
messages between the host and the guests of each room. The host's app runs
the game; the relay never looks inside the messages.

Anyone can run their own relay for their own friends. This guide shows how.

## What you need to know first

- **The key is the only gate.** The relay admits whoever holds its key and
  nobody else. There are no accounts. Anyone you give the link to can use
  your relay, so share it only with people you want to play with.
- **The relay keeps no data.** Rooms live in memory and disappear when the
  host leaves or the relay restarts. It writes nothing to disk, its
  filesystem is read-only, and its log holds only counts such as
  `room opened rooms=3 sockets=7`: no names, room codes, keys, addresses or
  messages.

## What you need

- A Linux machine with Docker and Docker Compose.
- A copy of this repository on that machine. The compose file builds the
  relay from it.
- A way to give the relay a public HTTPS address that passes WebSockets
  through: a Cloudflare Tunnel, or a reverse proxy such as Caddy, nginx or
  Traefik.

## 1. Make a key

The key is 32 random bytes written as 43 letters, digits, `-` and `_`. Make
one on the server and save it to a file that only uid 1000, the user the
relay runs as, can read:

```sh
sudo install -d -m 700 /srv/swiftie-relay
openssl rand 32 | basenc --base64url | tr -d = | sudo tee /srv/swiftie-relay/relay.key > /dev/null
sudo chown 1000:1000 /srv/swiftie-relay/relay.key
sudo chmod 600 /srv/swiftie-relay/relay.key
```

## 2. Start the relay

The relay joins an existing Docker network and publishes no ports, so only
the tunnel or proxy on that network can reach it. Create the network once,
tell the compose file where the key is, then start the relay from the
`relay/deploy` folder of the repository:

```sh
docker network create swiftie-edge
cd relay/deploy
printf 'RELAY_KEY_PATH=/srv/swiftie-relay/relay.key\n' > .env
docker compose up -d --build
docker compose ps
```

Within about half a minute `docker compose ps` shows the relay as healthy. Inside
the network it answers at `http://swiftie-relay:8080`. Every later
`docker compose` command in this guide runs from the same folder.

The compose file reads these settings from the `.env` file next to
`compose.yaml`:

| Setting | Default | What it does |
|---|---|---|
| `RELAY_KEY_PATH` | none, required | The key file on the server. |
| `RELAY_TRUST_CF_IP` | `false` | Set to `true` only behind a Cloudflare Tunnel; see below. |
| `RELAY_NETWORK` | `swiftie-edge` | The Docker network the relay joins. |

## 3. Put HTTPS in front of it

Players reach the relay over HTTPS, and the address must pass WebSockets
through.

**With a Cloudflare Tunnel**, run `cloudflared` on the same Docker network
and point a public hostname at `http://swiftie-relay:8080`. Cloudflare
passes WebSockets through by default. Turn on `RELAY_TRUST_CF_IP` and apply
it:

```sh
printf 'RELAY_TRUST_CF_IP=true\n' >> .env
docker compose up -d
```

Every player then reaches the relay from the tunnel's address, and Cloudflare
tells the relay each player's real address in a header. With the setting on,
the relay's limits apply to each player rather than to the tunnel as a whole.

Keep `RELAY_TRUST_CF_IP` set to `false` whenever the relay's port can be
reached without going through Cloudflare. Anyone who can reach the port
directly could otherwise send a made-up address in that header and dodge
the limits.

**With a reverse proxy**, put the proxy on the same Docker network and
forward your hostname to `swiftie-relay:8080`. In Caddy that takes one site
block, and Caddy passes WebSockets through on its own:

```text
relay.example.com {
	reverse_proxy swiftie-relay:8080
}
```

Leave `RELAY_TRUST_CF_IP` at `false` here. Every player then arrives from
the proxy's address, so the per-address limits below apply to all your
players together: at most 16 connections at once, and 10 wrong keys in 10
minutes locks everyone out for the rest of those 10 minutes.

To check the setup from any computer, open `https://<host>/` in a browser.
It shows a line naming Project Swiftie. On the server you can also check
the key:

```sh
curl -s -o /dev/null -w '%{http_code}\n' \
  -H "Authorization: Bearer $(sudo cat /srv/swiftie-relay/relay.key)" \
  -H 'x-swiftie-relay: 1' \
  https://<host>/v1/check
```

It prints `204` with the key and `401` without it.

## 4. Share the link

The link is the address with the key after a `#`:

```text
https://<host>/#<key>
```

Each friend copies the whole link into Project Swiftie, under Settings, Play
together, Server link. The part after `#` is never sent as part of the web
address; the app sends the key in a header instead.

## Cutting everyone off

To stop everyone who has the link, make a new key into the same file and
restart the relay:

```sh
openssl rand 32 | basenc --base64url | tr -d = | sudo tee /srv/swiftie-relay/relay.key > /dev/null
docker compose restart relay
```

The old link stops working at once and every open room closes. Share the
new link with the friends you still want to play with.

## Updating

Pull the repository and rebuild:

```sh
git pull
docker compose up -d --build
```

Everyone in a room needs the same version of Project Swiftie. A player on a
different version is turned away with a line asking them to update.

## Limits

The relay closes or refuses anything beyond these limits, so one
misbehaving copy cannot take it down for everyone else:

| Limit | Value |
|---|---|
| Connections at once | 200, and 16 from one address |
| Open rooms | 50 |
| Players in a room | 8 |
| Message size | 64 KiB |
| Messages per connection | 60 a second |
| Time to open or join a room after connecting | 10 seconds |
| Wrong keys from one address | 10 in 10 minutes, then refused until the 10 minutes pass |
| Memory | 128 MB |
