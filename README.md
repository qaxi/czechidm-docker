# CzechIDM - Docker

!!! Does not work - some Tomcat issue !!!

## Front Note

This is attempt to make CzechIDM Docker installation for demo purposes.

It is combination of https://github.com/bcvsolutions/CzechIdMng , https://github.com/bcvsolutions/czechidm-docker and https://github.com/bcvsolutions/tomcat-docker

## Quick start

```
# Docker Compose V2
docker compose up

# or

# Docker Compose V1
docker-compose up
```

## ToDo


- [x] make Docker images build separately
- [x] make Docker compose build
- [x] make Docker compose run containers
- [ ] make CzechIDM work
- [ ] remove dirty trick for building tomcat image dependency
- [ ] strip rpms from images
- [ ] strip Maven dependencies and build artifacts

## License

MIT License

## Quick notes

```
How to clean maven artifacts?
? geronimo-jms_1.1_spec-1.1.1.pom
? fakesmtp-2.0.jar
? maven clean
```
