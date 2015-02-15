# Use phusion/baseimage as base image. To make your builds reproducible, make
# sure you lock down to a specific version, not to `latest`!
# See https://github.com/phusion/baseimage-docker/blob/master/Changelog.md for
# a list of version numbers.
FROM phusion/baseimage:0.9.16

# Set correct environment variables.
ENV HOME /root

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

RUN apt update && apt-get -y install postgresql-9.3 postgresql-server-dev-9.3 build-essential libpq-dev lua5.2 liblua5.2-dev lighttpd ghc libghc-parsec3-dev imagemagick exim4 python-pip

RUN pip install markdown2

ADD scripts /tmp/

USER postgres
RUN service postgresql start &&\
    createuser -d -R -S www-data

USER root
RUN mkdir /root/install
WORKDIR /root/install
ADD http://www.public-software-group.org/pub/projects/liquid_feedback/backend/v3.0.4/liquid_feedback_core-v3.0.4.tar.gz liquid_feedback_core-v3.0.4.tar.gz
RUN tar -xvzf liquid_feedback_core-v3.0.4.tar.gz
WORKDIR /root/install/liquid_feedback_core-v3.0.4
RUN make
RUN mkdir /opt/liquid_feedback_core/ &&\
    cp core.sql lf_update lf_update_suggestion_order /opt/liquid_feedback_core/
WORKDIR /opt/liquid_feedback_core
RUN service postgresql start &&\
    su www-data -s /bin/sh -c "createdb liquid_feedback &&\
                               psql -v ON_ERROR_STOP=1 -f core.sql liquid_feedback &&\
                               psql -v ON_ERROR_STOP=1 -f /tmp/defaults.sql \
                               liquid_feedback &&\
                               psql -v ON_ERROR_STOP=1 -f /tmp/create_admin.sql \
                               liquid_feedback"

# Install WebMCP:
WORKDIR /root/install
ADD http://www.public-software-group.org/pub/projects/webmcp/v1.2.6/webmcp-v1.2.6.tar.gz webmcp-v1.2.6.tar.gz
RUN tar -xvzf webmcp-v1.2.6.tar.gz
WORKDIR webmcp-v1.2.6
RUN sed -i '/CFLAGS / s/$/ -I \/usr\/include\/lua5.2 -I \/usr\/include\/postgresql  -I \/usr\/include\/postgresql\/9.3\/server/' Makefile.options
RUN make
RUN mkdir /opt/webmcp && cp -RL framework/* /opt/webmcp/

# Install RocketWiki LqFb-Edition:
WORKDIR /root/install
ADD http://www.public-software-group.org/pub/projects/rocketwiki/liquid_feedback_edition/v0.4/rocketwiki-lqfb-v0.4.tar.gz rocketwiki-lqfb-v0.4.tar.gz
RUN tar -xvzf rocketwiki-lqfb-v0.4.tar.gz
WORKDIR rocketwiki-lqfb-v0.4
RUN make
RUN mkdir /opt/rocketwiki-lqfb &&\
    cp rocketwiki-lqfb rocketwiki-lqfb-compat /opt/rocketwiki-lqfb/

# Install LiquidFeedback-Frontend
WORKDIR /root/install
ADD http://www.public-software-group.org/pub/projects/liquid_feedback/frontend/v3.0.4/liquid_feedback_frontend-v3.0.4.tar.gz liquid_feedback_frontend-v3.0.4.tar.gz
RUN tar -xvzf liquid_feedback_frontend-v3.0.4.tar.gz
RUN mv liquid_feedback_frontend-v3.0.4 /opt/liquid_feedback_frontend
RUN chown www-data /opt/liquid_feedback_frontend/tmp

WORKDIR /opt/liquid_feedback_frontend/fastpath
RUN sed -i 's/testing\/app/frontend/' getpic.c
RUN make

WORKDIR /opt/liquid_feedback_frontend

# TODO: configure mail server
#RUN dpkg-reconfigure exim4-config

#Create webserver configuration for LiquidFeedback:
ADD config/60-liquidfeedback.conf /etc/lighttpd/conf-available/
RUN ln -s /etc/lighttpd/conf-available/60-liquidfeedback.conf /etc/lighttpd/conf-enabled/

ADD config/myconfig.lua /opt/liquid_feedback_frontend/config/myconfig.lua

ADD scripts/lf_updated /opt/liquid_feedback_core/lf_updated
ADD scripts/lf_notify /opt/liquid_feedback_frontend/lf_notify

ADD scripts/lf_update_run /etc/service/lf_updated/run
ADD scripts/lf_notify_run /etc/service/lf_notify/run
ADD scripts/start_lighttpd /etc/service/lighttpd/run
ADD scripts/start_psql /etc/service/psql/run
ADD scripts/start_exim /etc/service/exim/run


#EXPOSE 443

#ADD selfsigned.pem /etc/lighttpd/selfsigned.pem
#RUN chown www-data:www-data /etc/lighttpd/selfsigned.pem
#ADD config/10-ssl.conf /etc/lighttpd/conf-available/10-ssl.conf
#RUN ln -s  /etc/lighttpd/conf-available/10-ssl.conf  /etc/lighttpd/conf-enabled/10-ssl.conf

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
