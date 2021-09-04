FROM amazonlinux

# Install GnuCOBOL dependencies
RUN yum install tar gzip wget gcc make libgmp-dev gmp gmp-devel autoconf -y

# Install GNUCobol
RUN wget -O gnu-cobol.tar.gz https://nav.dl.sourceforge.net/project/gnucobol/gnucobol/2.2/gnucobol-2.2.tar.gz
RUN tar zxf gnu-cobol.tar.gz
WORKDIR gnucobol-2.2
RUN ./configure --without-db  --without-xml --without-json
RUN make
RUN make install

WORKDIR /app
RUN mkdir /app/lib

# Need to copy the dynamically linked libraries
#RUN cp /lib64/libc.so.6 /app/lib
RUN cp /usr/local/lib/libcob.so.4 /app/lib

# Copy and compile the program
COPY hello-world.cob .
RUN cobc -x hello-world.cob
RUN rm hello-world.cob
