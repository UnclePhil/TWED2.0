## TiddlyEsxDoc Config file
####################################
# VMware VirtualCenter server name #
# ----------------------------------
# This is an powershell array of vcenter processed in the same file
# Each Vcenter have 4 parameters
# IP or FQDN
# Port
# User name : can be a simple reader
# Passowrd : In clear text ...... yes i know ....:-(
#########################################################
$vcs=@(@("192.168.0.000","443","ReaderUser","HisBeautifulePassword"),@("toto","443","toto","toto")) 

####################################
##Running variables
##-----------------
## if you have a big infrastructure, you can limit the number of VM visited
## ZERO means : no limit
###################
$vmlimit = 0  ## ZERO equal No limit of analyzed Vm

##################
# Mail variables 
# -------------------------------------
# If you need to Send  the result file to anyone
# Fill the 4 following variables
#################################################
$enablemail = "yes"
$smtpServer = "smtp.domain.your"
$mailfrom = "vmadmin <vmAdmin@domain.your>"
$mailto = "you@domain.your"

#################
# Post processing command variables #
# -------------------------------------
# If you need to post the result file somewhere, you can use any command, 
# the full filename can be passed as !_FILENAME_! parameter
##################################################
$enablecmd = "no"
$cmddebug = "no"
$postprocesscmd = "c:\tools\pscp.exe -pw password !_FILENAME_! user@192.168.xxx.yyy:/var/www/mywebsite/cmdb/VMExport.html"

#################
# Script parameters
###################
$curdir="c:\ps\autotask\TWEDCurrent\" # the script base path WITH traling backslash
$basetemplate = "CMDB_Mini.html"  # template name relative to script path w
$reportname="Prefix"  # This is the prefix of the result file, it will be followed by the lauch date&time 
