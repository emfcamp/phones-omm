
# phones-omm

A Docker container for running the Mitel OMM SIP-DECT Controller

## Notes

- You have to supply your own OMM binaries, either as local files or through
  `OMM_URL` (see the md5sums section)
- Tested on versions 8.0, 9.1 and 10
- It replaces the `SIP-DECT.sh` start up script shipped with OMM with a custom, Docker friendly `entrypoint.sh`
- OMM and ICS logs are written to the `data` volume
- In future we'd like to move away from host networking, but we need to do some more testing
- Exposing SIP services like OMM to the internet is a bad idea, use a firewall
- Images are currently only available for the amd64 architecture
- There might be a better way of doing this, PRs are accepted

## Usage

Install docker, docker compose, etc.

In the directory of your docker compose project, create some directories:
```
mkdir data
mkdir config
mkdir bin
```
Place the `iprfp3G.dnld`, `iprfp4G.dnld` and `SIP-DECT.bin` files in the `bin`
directory. Alternatively, leave `bin` empty and set `OMM_URL` as described
below.

Create `compose.yml` so it looks something like:

```
services:
  omm:
    image: ghcr.io/emfcamp/phones-omm:latest
    network_mode: host
    cap_add:
      - NET_ADMIN
      - NET_RAW
      - NET_BIND_SERVICE
      - CAP_SYS_NICE
    security_opt:
      - seccomp=unconfined
    environment:
      OMM_URL: ${OMM_URL:-}
    volumes:
      - ./data:/opt/SIP-DECT
      - ./conf:/conf
      - ./bin:/firmware:ro
    restart: unless-stopped
```

Start OMM with:
`docker compose up -d`

### Environment variables

| Variable | Default | Description |
| --- | --- | --- |
| `OMM_HTTP_PORT` | `80` | HTTP listen port for the SIP-DECT web interface. |
| `OMM_HTTPS_PORT` | `443` | HTTPS listen port for the SIP-DECT web interface. |
| `OMM_NOROOT` | Unset | Adds `-noroot` when the variable is present (even when empty) |
| `OMM_URL` | Unset | URL of a SIP-DECT release ZIP. Used when `/opt/SIP-DECT/SIP-DECT.bin` and local firmware are absent. |

For example:

```yaml
services:
  omm:
    environment:
      OMM_HTTP_PORT: 81
      OMM_HTTPS_PORT: 444
      OMM_NOROOT: "1"
```

To download the firmware at first startup instead of putting it in `bin`, set
the release ZIP URL before starting Compose (the `/firmware` volume may remain
mounted and empty):

```console
export OMM_URL="https://downloads.example/SIP-DECT_9.1SP1-JD10/SIP-DECT_9.1SP1-JD10.zip"
docker compose up -d
```

The container extracts only `SIP-DECT.bin`, `iprfp3G.dnld` and
`iprfp4G.dnld`. They must be together either at the archive root or in a
top-level `SIP-DECT*` directory. The files are stored in the `data` volume, so
the download is not repeated on later starts.

## md5sums

### SIP-DECT_8.0SP1-EF04

| File | md5sum |
| -- | -- |
| `SIP-DECT.bin` | `7e1e540d48a5a3133f8edb28cc61e541` |
`iprfp3G.dnld` | `1784f83e56f1ede5ae9d4c3b11004916`|
| `iprfp4G.dnld` | `535d889a325c8f6bb010b39df5bf5f7a` |

### SIP-DECT 9.1SP1-JD10

| File | md5sum |
| -- | -- |
| `SIP-DECT.bin` | `e0c5a1ac873ecdd3c21dabb4a5f37353` |
`iprfp3G.dnld` | `6e5f3b7fc98b454c5dad2cfff7c06def`|
| `iprfp4G.dnld` | `db1779b98db3eae62627098b1dbf8281` |


###   SIP-DECT 10.0-HF02KF01

| File | md5sum |
| -- | -- |
| `SIP-DECT.bin` | `c84ef530256309777926361326562912` |
| `iprfp3G.dnld` | `c68a8a9a74c4b531ae4c37d92ccc2c0e`|
| `iprfp4G.dnld` | `80d154864b93f50307f9f255c722f32e` |


## License

GNU AGPLv3
