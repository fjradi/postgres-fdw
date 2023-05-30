ARG base_tag=15.2
FROM postgres:${base_tag} AS mssql

ARG TDS_FDW_VERSION=2.0.3
ARG SOURCE_FILES=/tmp/tds_fdw

RUN apt-get update;

# compilation deps
RUN apt-get install -y --no-install-recommends \
    make gcc gnupg \
    postgresql-server-dev-15 freetds-dev \
    # runtime deps
    libsybdb5 freetds-common;
# tds_fdw
RUN mkdir -p ${SOURCE_FILES};
COPY ./tds_fdw-${TDS_FDW_VERSION}.tar.gz ${SOURCE_FILES}/tds_fdw-${TDS_FDW_VERSION}.tar.gz
RUN tar --strip-components=1 -C ${SOURCE_FILES} -zxf ${SOURCE_FILES}/tds_fdw-${TDS_FDW_VERSION}.tar.gz; \
    cd ${SOURCE_FILES}; \
    # install
    make USE_PGXS=1; \
    make USE_PGXS=1 install;

FROM postgres:${base_tag} AS mysql

ARG MYSQL_FDW_VERSION=2_9_0
ARG SOURCE_FILES=/tmp/mysql_fdw

RUN apt-get update;

# compilation deps
RUN apt-get install -y --no-install-recommends \
    make gcc \
    postgresql-server-dev-15 libmariadb-dev-compat;

# download MYSQL_FDW source files
RUN mkdir -p ${SOURCE_FILES};
COPY ./mysql_fdw-REL-${MYSQL_FDW_VERSION}.tar.gz ${SOURCE_FILES}/mysql_fdw-REL-${MYSQL_FDW_VERSION}.tar.gz
RUN tar -C ${SOURCE_FILES} --strip-components=1 -zxf ${SOURCE_FILES}/mysql_fdw-REL-${MYSQL_FDW_VERSION}.tar.gz; \
    cd ${SOURCE_FILES}; \
    # compilation
    make USE_PGXS=1; \
    make USE_PGXS=1 install;

FROM postgres:${base_tag} AS oracle

ARG ORACLE_CLIENT_VERSION=18.5.0.0.0
ARG ORACLE_CLIENT_PATH=185000
ARG ORACLE_CLIENT_VERSION=19.8.0.0.0
ARG ORACLE_CLIENT_PATH=19800
ARG ORACLE_CLIENT_URL=https://download.oracle.com/otn_software/linux/instantclient/${ORACLE_CLIENT_PATH}/instantclient-basic-linux.x64-${ORACLE_CLIENT_VERSION}dbru.zip
ARG ORACLE_SQLPLUS_URL=https://download.oracle.com/otn_software/linux/instantclient/${ORACLE_CLIENT_PATH}/instantclient-sqlplus-linux.x64-${ORACLE_CLIENT_VERSION}dbru.zip
ARG ORACLE_SDK_URL=https://download.oracle.com/otn_software/linux/instantclient/${ORACLE_CLIENT_PATH}/instantclient-sdk-linux.x64-${ORACLE_CLIENT_VERSION}dbru.zip

ENV ORACLE_HOME=/usr/lib/oracle/client

RUN apt-get update; \
    apt-get install -y --no-install-recommends ca-certificates wget unzip; \
    # instant client
    wget -O instant_client.zip ${ORACLE_CLIENT_URL}; \
    unzip instant_client.zip; \
    # sqlplus
    wget -O sqlplus.zip ${ORACLE_SQLPLUS_URL}; \
    unzip sqlplus.zip; \
    # sdk
    wget -O sdk.zip ${ORACLE_SDK_URL}; \
    unzip sdk.zip; \
    # install
    mkdir -p ${ORACLE_HOME}; \
    mv instantclient*/* ${ORACLE_HOME}; \
    rm -r instantclient*; \
    rm instant_client.zip sqlplus.zip sdk.zip; \
    # required runtime libs: libaio
    apt-get install -y --no-install-recommends libaio1; \
    apt-get purge -y --auto-remove

ENV PATH $PATH:${ORACLE_HOME}


ARG ORACLE_FDW_VERSION=2_5_0
ARG ORACLE_FDW_URL=https://github.com/laurenz/oracle_fdw/archive/ORACLE_FDW_${ORACLE_FDW_VERSION}.tar.gz
ARG SOURCE_FILES=tmp/oracle_fdw

# oracle_fdw
RUN mkdir -p ${SOURCE_FILES}; \
    wget -O - ${ORACLE_FDW_URL} | tar -zx --strip-components=1 -C ${SOURCE_FILES}; \
    cd ${SOURCE_FILES}; \
    # install
    apt-get install -y --no-install-recommends make gcc postgresql-server-dev-15; \
    make; \
    make install; \
    echo ${ORACLE_HOME} > /etc/ld.so.conf.d/oracle_instantclient.conf; \
    ldconfig; \
    # cleanup
    apt-get purge -y --auto-remove postgresql-server-dev-15 gcc make

# FROM postgres:${base_tag}

# ARG extdir=/usr/share/postgresql/15/extension
# ARG extlibdir=/usr/lib/postgresql/15/lib
# ARG libdir=/usr/lib/aarch64-linux-gnu

# COPY --from=mssql ${extdir}/tds_fdw* ${extdir}/
# COPY --from=mssql ${extlibdir}/tds_fdw.so ${extlibdir}/
# COPY --from=mssql ${libdir}/*sybdb* ${libdir}/

# COPY --from=mysql ${extdir}/mysql_fdw* ${extdir}/
# COPY --from=mysql ${extlibdir}/mysql_fdw.so ${extlibdir}/
# COPY --from=mysql ${libdir}/*mysql* ${libdir}/
# COPY --from=mysql ${libdir}/libmariadb3/ ${libdir}/libmariadb3/

# ENV ORACLE_HOME /usr/lib/oracle/client
# ENV PATH $PATH:${ORACLE_HOME}
# ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:${ORACLE_HOME}

# COPY --from=oracle ${extdir}/oracle_fdw* ${extdir}/
# COPY --from=oracle ${extlibdir}/oracle_fdw.so ${extlibdir}/
# COPY --from=oracle ${libdir}/*libaio* ${libdir}/
# COPY --from=oracle ${ORACLE_HOME}/ ${ORACLE_HOME}/

# COPY init.sql /docker-entrypoint-initdb.d/