import os

analysis = '/project/bbl_roalf_7tglucestage/analysis/'
script = os.path.join(analysis, 'scripts/process_cest_hippocampus.sh')
dicoms = os.path.join(analysis, 'preprocessing', 'cest')
cest = os.path.join(analysis, 'postprocessing', 'cest_out')
atlas = os.path.join(analysis, 'atlases')
structural = os.path.join(analysis, 'postprocessing', 'structural_out')
# ants = '/appl/ANTs-2.3.1/bin/'
log = os.path.join(analysis, 'logs/cest/logs')
sub_scripts = os.path.join(analysis, 'logs/cest/scripts')

# get the list of cases in dicoms folder
dicom_cases = os.listdir(dicoms)

# iterate through the structural folder to get the subject and session ids
for sub in os.listdir(structural):
    sub_dir = os.path.join(structural, sub)

    for ses in os.listdir(sub_dir):

        # find corresponding 'case' for sub and ses
        [case] = [case for case in dicom_cases if sub in case]
        dicom_cases.remove(case)

        # make command to run process_cest_hippocampus.sh
        cmd = [script, structural, dicoms,
               cest, atlas, log, sub, ses, case]
        cmd = ' '.join(cmd)
        cmd_file = os.path.join(sub_scripts, case + '.sh')

        os.system("printf '" + cmd + "' >> " + cmd_file)
        os.system('chmod ug+x ' + cmd_file)
        os.system('bsub bash ' + cmd_file)
