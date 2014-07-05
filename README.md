liquid_feedback_docker
======================

This should set up a docker container running liquid feedback.

Based on http://dev.liquidfeedback.org/trac/lf/wiki/installation.

Generate ```./selfsigned.pem``` or get a proper certificate somewhere.


Build with
```
docker build -t dimsumlabs/lqfb .
```


Run with
```
docker run -p 443:443 -p 80:80 -i -t dimsumlabs/lqfb /sbin/my_init -- bash -l
```
