import os

project = '/project/bbl_roalf_7tglucestage/analysis'
rawdata = os.path.join(project, 'rawdata')
out = os.path.join(project, 'data')
convert = os.path.join(project, 'scripts', 'convert2nifti.sh')

for case in os.listdir(rawdata):
    
    if not os.path.isdir(os.path.join(out, case)):
        cmd = ['bsub', convert, rawdata, out, case]
        os.system(' '.join(cmd))

