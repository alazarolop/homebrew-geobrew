class SagaGis < Formula
  desc "System for Automated Geoscientific Analyses - Long Term Support"
  homepage "http://saga-gis.org"
  url "https://downloads.sourceforge.net/project/saga-gis/SAGA%20-%207/SAGA%20-%207.9.0/saga-7.9.0.tar.gz"
  sha256 "a1bdb725b42707134ed5003ccd484b8e0a3960147dd29c26f094fad9bb0f05d8"

  head "https://git.code.sf.net/p/saga-gis/code.git"

  depends_on "automake" => :build
  depends_on "autoconf" => :build
  depends_on "libtool" => :build
  depends_on "pkg-config" => :build
  depends_on "python@3.8"
  depends_on "wxmac"
  depends_on "wxpython"
  depends_on "geos"
  depends_on "jasper"
  depends_on "fftw"
  depends_on "libtiff"
  depends_on "swig"
  depends_on "xz" # lzma
  depends_on "giflib"
  depends_on "opencv@3"
  depends_on "unixodbc"
  depends_on "libharu"
  depends_on "qhull" # instead of looking for triangle
  depends_on "poppler"
  depends_on "sqlite"
  depends_on "hdf5"
  depends_on "proj"
  depends_on "netcdf"
  depends_on "gdal"
  depends_on "libomp"
  depends_on "postgresql" 
  
  # SKIP liblas support until SAGA supports > 1.8.1, which should support GDAL 2;
  #      otherwise, SAGA binaries may lead to multiple GDAL versions being loaded
  # See: https://github.com/libLAS/libLAS/issues/106
  #      Update: https://github.com/libLAS/libLAS/issues/106
  #depends_on "osgeo-laszip@2"
  #depends_on "osgeo-liblas"

  # Vigra support builds, but dylib in saga shows 'failed' when loaded
  # Also, using --with-python will trigger vigra to be built with it, which
  # triggers a source (re)build of boost --with-python
  #depends_on "osgeo-vigra" => :optional

  # resource "app_icon" do
  #   url "https://osgeo4mac.s3.amazonaws.com/src/saga_gui.icns"
  #   sha256 "288e589d31158b8ffb9ef76fdaa8e62dd894cf4ca76feabbae24a8e7015e321f"
  # end

  def install
    ENV.cxx11

    # https://sourceforge.net/p/saga-gis/wiki/Compiling%20SAGA%20on%20Mac%20OS%20X/
    # configure FEATURES CXX="CXX" CPPFLAGS="DEFINES GDAL_H $PROJ_H" LDFLAGS="GDAL_SRCH PROJ_SRCH LINK_MISC"

    # cppflags : wx-config --version=3.0 --cppflags
    # defines : -D_FILE_OFFSET_BITS=64 -DWXUSINGDLL -D__WXMAC__ -D__WXOSX__ -D__WXOSX_COCOA__
    cppflags = "-I#{HOMEBREW_PREFIX}/lib/wx/include/osx_cocoa-unicode-3.0 -I#{HOMEBREW_PREFIX}/include/wx-3.0 -D_FILE_OFFSET_BITS=64 -DWXUSINGDLL -D__WXMAC__ -D__WXOSX__ -D__WXOSX_COCOA__"

    # libs : wx-config --version=3.0 --libs
    ldflags = "-L#{HOMEBREW_PREFIX}/lib -framework IOKit -framework Carbon -framework Cocoa -framework AudioToolbox -framework System -framework OpenGL " # -lwx_osx_cocoau_xrc-3.0 -lwx_osx_cocoau_qa-3.0  -lwx_baseu_xml-3.0 -lwx_baseu_net-3.0 -lwx_baseu-3.0 -lwx_osx_cocoau_adv-3.0 -lwx_osx_cocoau_core-3.0 -lwx_osx_cocoau_html-3.0  -lwx_osx_cocoau_webview-3.0

    # xcode : xcrun --show-sdk-path
    # -mmacosx-version-min=10.15 -isysroot /Library/Developer/CommandLineTools/SDKs/MacOSX.sdk
    link_misc = "-arch x86_64 -lstdc++"
    
    ENV.append "CPPFLAGS", "-I#{Formula["proj"].opt_include} -I#{Formula["gdal"].opt_include} #{cppflags}"
    ENV.append "LDFLAGS", "-L#{Formula["proj"].opt_lib} -lproj -L#{Formula["gdal"].opt_lib} -lgdal #{link_misc} #{ldflags}"

    # Disable narrowing warnings when compiling in C++11 mode.
    ENV.append "CXXFLAGS", "-Wno-c++11-narrowing -std=c++11"

    ENV.append "PYTHON_VERSION", "3.8"
    ENV.append "PYTHON", "#{Formula["python@3.8"].opt_bin}/python3"

    # support for PROJ 6
    # ENV.append_to_cflags "-DACCEPT_USE_OF_DEPRECATED_PROJ_API_H"
    # saga lts does not support proj 6
    # https://github.com/OSGeo/proj.4/wiki/proj.h-adoption-status
    # https://sourceforge.net/p/saga-gis/bugs/271/

    # cd "saga-gis"

    # fix homebrew-specific header location for qhull
    inreplace "src/tools/grid/grid_gridding/nn/delaunay.c", "qhull/", "libqhull/" # if build.with? "qhull"

    # libfire and triangle are for non-commercial use only, skip them
    args = %W[
      --prefix=#{prefix}
      --disable-dependency-tracking
      --disable-libfire
      --disable-triangle
      --enable-shared
      --enable-debug
      --enable-python
      --disable-gui 
    ]
    #--disable-openmp
    #--enable-gui
    #--enable-unicode

    args << "--with-postgresql=#{Formula["postgresql"].opt_bin}/pg_config" # if build.with? "postgresql"

    system "autoreconf", "-i"
    system "./configure", *args
    system "make", "install"
  end

  test do
    output = `#{bin}/saga_cmd --help`
    assert_match /The SAGA command line interpreter/, output
  end
end
