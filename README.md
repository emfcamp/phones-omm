# phones-omm

A Docker container for running the Mitel OMM SIP-DECT Controller

## Notes

- You have to supply your own OMM binaries (see the md5sums section)
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
Place the `iprfp3G.dnld`,  `iprfp4G.dnld`  and `SIP-DECT.bin` files in the `bin` directory.

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
    volumes:
      - ./data:/opt/SIP-DECT
      - ./conf:/conf
      - ./bin/SIP-DECT.bin:/opt/SIP-DECT/SIP-DECT.bin:ro
      - ./bin/iprfp3G.dnld:/opt/SIP-DECT/iprfp3G.dnld:ro
      - ./bin/iprfp4G.dnld:/opt/SIP-DECT/iprfp4G.dnld:ro
    restart: unless-stopped
```

Start OMM with:
`docker compose up -d`

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
`iprfp3G.dnld` | `c68a8a9a74c4b531ae4c37d92ccc2c0e`|
| `iprfp4G.dnld` | `80d154864b93f50307f9f255c722f32e` |


## License

GNU AGPLv3
