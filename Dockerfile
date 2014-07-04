# Use phusion/baseimage as base image. To make your builds reproducible, make
# sure you lock down to a specific version, not to `latest`!
# See https://github.com/phusion/baseimage-docker/blob/master/Changelog.md for
# a list of version numbers.
FROM debian:squeeze

# Set correct environment variables.
ENV HOME /root

# Regenerate SSH host keys. baseimage-docker does not contain any, so you
# have to do that yourself. You may also comment out this instruction; the
# init system will auto-generate one during boot.
#RUN /etc/my_init.d/00_regen_ssh_host_keys.sh

RUN sed -i "s/archive.ubuntu.com/ftp.cuhk.edu.hk\/pub\/Linux/" /etc/apt/sources.list
RUN apt-get update
RUN apt-get -y upgrade
RUN apt-get -y install lua5.1 postgresql build-essential libpq-dev liblua5.1-0-dev lighttpd ghc libghc6-parsec3-dev imagemagick exim4
RUN apt-get -y install wget

USER postgres
RUN /etc/init.d/postgresql start && createuser -d -R -S www-data

USER root
RUN mkdir /root/install
WORKDIR /root/install
RUN wget http://www.public-software-group.org/pub/projects/liquid_feedback/backend/v2.2.1/liquid_feedback_core-v2.2.1.tar.gz
RUN tar -xvzf liquid_feedback_core-v2.2.1.tar.gz
WORKDIR liquid_feedback_core-v2.2.1
RUN make
RUN mkdir /opt/liquid_feedback_core
RUN cp core.sql lf_update /opt/liquid_feedback_core/
WORKDIR /opt/liquid_feedback_core
RUN su postgres -c "/etc/init.d/postgresql start" \
    && su www-data -c "createdb liquid_feedback" \
    && su www-data -c "createlang plpgsql liquid_feedback" \
    && su www-data -c "psql -v ON_ERROR_STOP=1 -f core.sql liquid_feedback" \
    && su www-data -c "psql liquid_feedback"

# Install WebMCP:
WORKDIR /root/install
RUN wget http://www.public-software-group.org/pub/projects/webmcp/v1.2.5/webmcp-v1.2.5.tar.gz
RUN tar -xvzf webmcp-v1.2.5.tar.gz
WORKDIR webmcp-v1.2.5
RUN sed -i '/CFLAGS / s/$/ -I \/usr\/include\/lua5.1/' Makefile.options
RUN make
RUN mkdir /opt/webmcp
RUN cp -RL framework/* /opt/webmcp/

# Install RocketWiki LqFb-Edition:
WORKDIR /root/install
RUN wget http://www.public-software-group.org/pub/projects/rocketwiki/liquid_feedback_edition/v0.4/rocketwiki-lqfb-v0.4.tar.gz
RUN tar -xvzf rocketwiki-lqfb-v0.4.tar.gz
WORKDIR rocketwiki-lqfb-v0.4
RUN make
RUN mkdir /opt/rocketwiki-lqfb
RUN cp rocketwiki-lqfb rocketwiki-lqfb-compat /opt/rocketwiki-lqfb/

# Install LiquidFeedback-Frontend v2.2.1
WORKDIR /root/install
RUN wget http://www.public-software-group.org/pub/projects/liquid_feedback/frontend/v2.2.1/liquid_feedback_frontend-v2.2.1.tar.gz
RUN tar -xvzf liquid_feedback_frontend-v2.2.1.tar.gz
RUN mv liquid_feedback_frontend-v2.2.1 /opt/liquid_feedback_frontend

# Create HTML code for help texts:
#WORKDIR /opt/liquid_feedback_frontend/locale
#RUN PATH=/opt/rocketwiki-lqfb:$PATH make
# the above doesn't build

RUN chown www-data /opt/liquid_feedback_frontend/tmp
WORKDIR /opt/liquid_feedback_frontend/fastpath
RUN sed -i 's/testing\/app/frontend/' getpic.c
RUN make

# TODO: configure mail server
#RUN dpkg-reconfigure exim4-config

#Create webserver configuration for LiquidFeedback:
ADD 60-liquidfeedback.conf /etc/lighttpd/conf-available/
RUN ln -s /etc/lighttpd/conf-available/60-liquidfeedback.conf /etc/lighttpd/conf-enabled/

# Configure LiquidFeedback-Frontend:








# Clean up APT when done.
#RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
