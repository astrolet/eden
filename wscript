import os, shutil

srcdir = './swe'
blddir = 'build'
VERSION = '1.77.00-1'

def set_options(opt):
  opt.tool_options('compiler_cc')

def configure(conf):
  conf.check_tool('compiler_cc')

def build(bld):
  path = os.path.abspath('.')
  os.chdir(os.path.join('swe', 'src'))
  os.system('make clean')
  #os.system('make libswe.a')
  os.system('make libswe.so')
  
  shutil.move('libswe.so', os.path.join('..', '..', 'lib', 'swe.dylib'))
  os.chdir(path)

  # obj = bld.new_task_gen('cc', 'libswe.so')
  # obj.target = 'libswe.so'
  # obj.source = ['swedate.c', 'swehouse.c', 'swejpl.c', 'swemmoon.c', 'swemplan.c', 'swepcalc.c', 'sweph.c', 'swepdate.c', 'swephlib.c', 'swecl.c', 'swehel.c']
