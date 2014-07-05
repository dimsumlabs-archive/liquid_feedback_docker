liquid_feedback_docker
======================

This should set up a docker container running liquid feedback.

Based on http://dev.liquidfeedback.org/trac/lf/wiki/installation.

Build with
```
docker build -t dimsumlabs/lqfb .
```

run with
```
docker run -p 8080:80 -i -t dimsumlabs/lqfb /sbin/my_init -- bash -l
```
