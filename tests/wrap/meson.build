project('parse-ini', 'c')
inih = subproject('inih', default_options: ['default_library=static', 'with_INIReader=false', 'distro_install=false', 'tests=false'])
parser = executable('parse-ini', 'main.c', dependencies: inih.get_variable('inih_dep'), install: true)
test('parse a setting', parser)
