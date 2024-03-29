class PgsqlOgrFdw < Formula
  desc "PostgreSQL foreign data wrapper for OGR"
  homepage "https://github.com/pramsey/pgsql-ogr-fdw"
  #url "https://github.com/pramsey/pgsql-ogr-fdw/archive/v1.0.8.tar.gz"
  #sha256 "4ab0c303006bfd83dcd40af4d53c48e7d8ec7835bb98491bc6640686da788a8b"
  url "https://github.com/pramsey/pgsql-ogr-fdw.git",
    :branch => "master",
    :commit => "d217483cea4303cbbd7c59bd0381a75c4710a331"
  version "1.1.4"

  #revision 1
  
  depends_on "alazarolop/geobrew/postgis@15"
  depends_on "gdal"
  depends_on "postgresql@15"


  def install
    ENV.deparallelize

    ENV.append "CFLAGS", "-Wl,-z,relro,-z,now"

    # This includes PGXS makefiles and so will install __everything__
    # into the Postgres keg instead of the this formula's keg.
    # Right now, no items installed to Postgres keg need to be installed to `prefix`.
    # In the future, if `make install` installs things that should be in `prefix`
    # consult postgis formula to see how to split it up.

    rm "#{buildpath}/Makefile"

    postgresql_ver = "#{Formula["postgresql@15"].opt_bin}"

    # Fix bin install path
    # Use CFLAGS from environment
    # From MakeFile https://www.pgxn.org/dist/ogr_fdw/
    config = <<~EOS
      # ogr_fdw/Makefile

      MODULE_big = ogr_fdw
      OBJS = ogr_fdw.o ogr_fdw_deparse.o ogr_fdw_common.o ogr_fdw_func.o stringbuffer_pg.o
      EXTENSION = ogr_fdw
      DATA = ogr_fdw--1.0--1.1.sql ogr_fdw--1.1.sql

      REGRESS = ogr_fdw

      EXTRA_CLEAN = sql/*.sql expected/*.out

      GDAL_CONFIG = #{Formula["gdal"].opt_bin}/gdal-config
      GDAL_CFLAGS = $(shell $(GDAL_CONFIG) --cflags)
      GDAL_LIBS = $(shell $(GDAL_CONFIG) --libs)

      PG_CONFIG = #{postgresql_ver}/pg_config
      REGRESS_OPTS = --encoding=UTF8

      PG_CPPFLAGS += $(GDAL_CFLAGS)
      LIBS += $(GDAL_LIBS)
      SHLIB_LINK := $(LIBS)

      PGXS := $(shell $(PG_CONFIG) --pgxs)
      include $(PGXS)

      PG_VERSION_NUM = $(shell awk '/PG_VERSION_NUM/ { print $$3 }' $(shell $(PG_CONFIG) --includedir-server)/pg_config.h)
      HAS_IMPORT_SCHEMA = $(shell [ $(PG_VERSION_NUM) -ge 90500 ] && echo yes)

      # order matters, file first, import last
      REGRESS = file pgsql
      ifeq ($(HAS_IMPORT_SCHEMA),yes)
      REGRESS += import
      endif

      ###############################################################
      # Build the utility program after PGXS to override the
      # PGXS environment

      CFLAGS = $(GDAL_CFLAGS) $(CFLAGS)
      LIBS = $(GDAL_LIBS)

      ogr_fdw_info$(X): ogr_fdw_info.o ogr_fdw_common.o stringbuffer.o
      	$(CC) $(CFLAGS) -o $@ $^ $(LIBS)

      clean-exe:
      	rm -f ogr_fdw_info$(X) ogr_fdw_info.o stringbuffer.o

      install-exe: all
      	# $(INSTALL_PROGRAM) ogr_fdw_info$(X) '$(DESTDIR)$(bindir)'
        # or $(INSTALL_PROGRAM) -D ogr_fdw_info$(X) '$(DESTDIR)$(bindir)/ogr_fdw_info$(X)'

      all: ogr_fdw_info$(X)

      clean: clean-exe

      install: install-exe
    EOS

    (buildpath/"Makefile").write config

    system "make"
    system "make", "DESTDIR=#{prefix}", "install"

    #mv "#{prefix}/usr/local/lib", "#{lib}"
    #mv "#{prefix}/usr/local/share", "#{share}"
    #rm_f "#{prefix}/usr"

    bin.install "ogr_fdw_info"
    prefix.install "data"

  end

  def caveats;
    <<~EOS
      For info on using extension, read the included REAMDE.md or visit:
        https://github.com/pramsey/pgsql-ogr-fdw

      PostGIS plugin libraries installed to:
        /usr/local/lib/postgresql
      PostGIS extension modules installed to:
       /usr/local/share/postgresql/extension
    EOS
  end

  test do
    # test the sql generator for the extension
    data_sub = "data".upcase # or brew audit thinks there is a D A T A section
    sql_out = <<~EOS

      CREATE SERVER myserver
        FOREIGN #{data_sub} WRAPPER ogr_fdw
        OPTIONS (
        	datasource '#{prefix}/data',
        	format 'ESRI Shapefile' );

      CREATE FOREIGN TABLE pt_two (
        fid bigint,
        geom Geometry(Point,4326),
        name varchar(50),
        age integer,
        height doubleprecision,
        birthdate date
      ) SERVER "myserver"
      OPTIONS (layer 'pt_two');

    EOS

    result = shell_output("ogr_fdw_info -s #{prefix}/data -l pt_two")
    assert_equal sql_out.gsub(' ',''), result.gsub(' ','')
  end
end
