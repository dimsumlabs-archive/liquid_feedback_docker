# Use phusion/baseimage as base image. To make your builds reproducible, make
# sure you lock down to a specific version, not to `latest`!
# See https://github.com/phusion/baseimage-docker/blob/master/Changelog.md for
# a list of version numbers.
FROM phusion/baseimage:0.9.9

# Set correct environment variables.
ENV HOME /root

# Regenerate SSH host keys. baseimage-docker does not contain any, so you
# have to do that yourself. You may also comment out this instruction; the
# init system will auto-generate one during boot.
RUN /etc/my_init.d/00_regen_ssh_host_keys.sh

# Use baseimage-docker's init system.
CMD ["/sbin/my_init"]

RUN sed -i "s/archive.ubuntu.com/ftp.cuhk.edu.hk\/pub\/Linux/" /etc/apt/sources.list
RUN apt-get update
RUN apt-get -y upgrade
RUN apt-get -y install lua5.1 postgresql build-essential libpq-dev liblua5.1-0-dev lighttpd ghc libghc6-parsec3-dev imagemagick postfix
RUN apt-get -y install wget

ADD scripts /tmp/

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
RUN cp core.sql lf_update lf_update_suggestion_order /opt/liquid_feedback_core/
WORKDIR /opt/liquid_feedback_core
RUN ls -lah /tmp/
RUN su postgres -c "/etc/init.d/postgresql start" \
    && su www-data -c "createdb liquid_feedback" \
    && su www-data -c "psql -v ON_ERROR_STOP=1 -f core.sql liquid_feedback" \
    && su www-data -c "psql liquid_feedback < /tmp/defaults.sql"
#    && su www-data -c "createlang plpgsql liquid_feedback" \


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

# Create HTML code for help texts (lots of errors but seems to work anyway)
WORKDIR /opt/liquid_feedback_frontend/locale/help
RUN for file in *.txt; do /opt/rocketwiki-lqfb/rocketwiki-lqfb < $file > $file.html; done

RUN chown www-data /opt/liquid_feedback_frontend/tmp
WORKDIR /opt/liquid_feedback_frontend/fastpath
RUN sed -i 's/testing\/app/frontend/' getpic.c
RUN make

# TODO: configure mail server
#RUN dpkg-reconfigure exim4-config

#Create webserver configuration for LiquidFeedback:
ADD config/60-liquidfeedback.conf /etc/lighttpd/conf-available/
RUN ln -s /etc/lighttpd/conf-available/60-liquidfeedback.conf /etc/lighttpd/conf-enabled/

# Configure LiquidFeedback-Frontend:
ADD config/myconfig.lua /opt/liquid_feedback_frontend/config/myconfig.lua
WORKDIR /opt/liquid_feedback_core
RUN su postgres -c "/etc/init.d/postgresql start" && su www-data -c "./lf_update dbname=liquid_feedback && echo OK"

USER root
ADD scripts/lf_updated /opt/liquid_feedback_core/lf_updated
ADD scripts/lf_update_run /etc/service/lf_updated/run
ADD scripts/start_lighttpd /etc/service/lighttpd/run
ADD scripts/start_psql /etc/service/psql/run
ADD scripts/postfix /etc/service/postfix/run

WORKDIR /opt/liquid_feedback_frontend/

# this command hangs for some reason
#RUN su postgres  -c "/etc/init.d/postgresql start" && \
#    su www-data -c "echo 'Event:send_notifications_loop()' | ../webmcp/bin/webmcp_shell myconfig"

WORKDIR /opt/liquid_feedback_core
RUN su postgres -c "/etc/init.d/postgresql start" && \
    su www-data -c "psql liquid_feedback < /tmp/create_admin.sql"

WORKDIR /root

EXPOSE 443

ADD selfsigned.pem /etc/lighttpd/selfsigned.pem
RUN chown www-data:www-data /etc/lighttpd/selfsigned.pem
ADD config/10-ssl.conf /etc/lighttpd/conf-available/10-ssl.conf
RUN ln -s  /etc/lighttpd/conf-available/10-ssl.conf  /etc/lighttpd/conf-enabled/10-ssl.conf

# Clean up APT when done.
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*




