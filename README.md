liquid_feedback_docker
======================

This should set up a docker container running liquid feedback.

Based on `http://www.public-software-group.org/mercurial/liquid_feedback_frontend/raw-file/tip/INSTALL.html`.

Edit the following files to your liking:
```
├── Dockerfile
├── config
│   ├── 10-ssl.conf
│   ├── 60-liquidfeedback.conf
│   └── myconfig.lua
```

If you want to use SSL: generate ```./selfsigned.pem``` or get a proper certificate somewhere,
```
openssl genrsa -des3 -out testing.key 2048
openssl req -new -key testing.key -out testing.csr
openssl x509 -req -days 365 -in testing.csr -signkey testing.key -out testing.crt
cat testing.key testing.crt > selfsigned.pem
```
and comment out the following lines in the `Dockerfile`
```
EXPOSE 443

ADD selfsigned.pem /etc/lighttpd/selfsigned.pem
RUN chown www-data:www-data /etc/lighttpd/selfsigned.pem
ADD config/10-ssl.conf /etc/lighttpd/conf-available/10-ssl.conf
RUN ln -s  /etc/lighttpd/conf-available/10-ssl.conf  /etc/lighttpd/conf-enabled/10-ssl.conf
```

Build with
```
docker build -t dimsumlabs/lqfb .
```
Run with
```
docker run -p 443:443 -p 80:80 -i -t dimsumlabs/lqfb /sbin/my_init -- bash -l
```

Configure exim `dpkg-reconfigure exim4-config` and you should be good to go.
