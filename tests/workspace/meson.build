project('drvc-workspace', 'c')
fs = import('fs')
subdir('pkg')
foreach member : ['cmd/api', 'cmd/worker']
  if fs.is_dir(member)
    subdir(member)
  endif
endforeach
