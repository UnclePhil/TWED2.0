###########################################################################################
# Title:	VMware to tiddlywiki CMDB 
# Credit:	
#      based on 
#			healtcheck.sp1 Ivo Beerens  www.ivobeerens.nl    	
#      		vcheck of Al : www.virtu-al.net
#			A lot of good other scripts
#           And the Powerclie Reference Book
# Created by: Ph Koenig	 			
# Date:		Sept 2009				
# Version:   			
# Website:	blog.unclephil.net
# E-mail:	philippe@unclephil.net koenigphil@gmail.com
########################################################################################### 
##Version
##############################
## 2.2  ESX Hba
##
## 2.1  Esx config completion
##        NTP service 
##      Cluster HA & Drs
##
## 2.0  Multiple vcenter documentation
##		split program in function
##		Add DC  tiddler 
##
## 1.7  Add cpu ready time stats into vm (peeter)
##      Some bug corrected
## 1.6  Externalisation of config file
##      modif cluster tiddler : heath overview
##      bug correction in VM calculation
## 1.5  Extend TW writing for Additional fields
##      Add summary field  for ESX 
## 1.4	Add snapshot flag for each vm
##      Esx Service console (from Al)
##		ESX vmotion ( from Al)
## 1.3  Add Multiple recipient for email
##		ability to limit number of vm analysed
##		Add Datastore details
## 1.2  Add Datastore summary
## 1.1  Modify some VM settings
## 1.0  Base build
###########################################################################################
param( [string] $CFG)

Clear-Host

##################################################
# USED FUNCTION #
##################################################
##############################

function TiddlyCompat ( [string] $Tfile )
{
[regex] $myregex = "</div><!--POST-STOREAREA-->"
$c = Get-Content $Tfile
$cpt = $c -match $myregex

}

function TiddlyAdd ([string] $Tinject, [string] $Tfile )
{
[regex] $myregex = "</div><!--POST-STOREAREA-->"
$c = Get-Content $Tfile
$myinject=$Tinject+"</div><!--POST-STOREAREA-->"
$nc = $c -replace $myregex, $myinject 
$nc | Set-Content $Tfile
Write-Host "--- Save data to file ---"
}

function TiddlerBuild ( [string] $TTitle, [string] $TTags, [string] $Tfields ,[string] $TContent )
{
##Remark
## $Tfields must be in format 'field1="ccccc" field2="bbbbb"'

$indate = Get-Date -format "yyyyMMddHHmm"
$rpl = '<div title="' + $TTitle + '" modifier="Powershell" created="'+$indate+'" modified="'+$indate+'" tags="' + $TTags + '" ' + $Tfields + '>'+'`n'
$rpl += "<pre>"+"`n"+$TContent+"</pre>"+"`n"
$rpl += "</div>"+"`n"

return $rpl
}


function Get-VmSize($xvm)
{
    #Initialize variables
    $VmDirs =@()
    $VmSize = 0

    $searchSpec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
    $searchSpec.details = New-Object VMware.Vim.FileQueryFlags
    $searchSpec.details.fileSize = $TRUE

    Get-View -VIObject $xvm | % {
        #Create an array with the vm's directories
        $VmDirs += $_.Config.Files.VmPathName.split("/")[0]
        $VmDirs += $_.Config.Files.SnapshotDirectory.split("/")[0]
        $VmDirs += $_.Config.Files.SuspendDirectory.split("/")[0]
        $VmDirs += $_.Config.Files.LogDirectory.split("/")[0]
        #Add directories of the vm's virtual disk files
        foreach ($disk in $_.Layout.Disk) {
            foreach ($diskfile in $disk.diskfile){
                $VmDirs += $diskfile.split("/")[0]
            }
        }
        #Only take unique array items
        $VmDirs = $VmDirs | Sort | Get-Unique

        foreach ($dir in $VmDirs){
            $ds = Get-Datastore ($dir.split("[")[1]).split("]")[0]
            $dsb = Get-View (($ds | get-view).Browser)
            $taskMoRef  = $dsb.SearchDatastoreSubFolders_Task($dir,$searchSpec)
            $task = Get-View $taskMoRef 

            while($task.Info.State -eq "running" -or $task.Info.State -eq "queued"){$task = Get-View $taskMoRef }
            foreach ($result in $task.Info.Result){
                foreach ($file in $result.File){
                    $VmSize += $file.FileSize
                }
            }
        }
    }

    return $VmSize
}

#########################################################
## End of used function


###############################################################
## DATACENTER Processing 
## TODO --
##    * vswitch configuration    
#################################

function Process-Datacenter ($filelocation, $vcserver) {
 Write-Host "Parsing: Datacenter ======"
 $toinject = ""
 
 $dcs = Get-Datacenter
 foreach ($dc in $dcs){
	$fields = ""
	$Tags="DC"
	$Tiddlertitle = $dc
	##DC location
	$ct += "!Location" +$crlf
	$ct += "*Vcenter : [[$vcserver]] " +$crlf
	
	##Write Tiddler
	$toinject += TiddlerBuild $Tiddlertitle $Tags $fields $ct
	}
##inject tiddler in file
Tiddlyadd $toinject $filelocation
Clear-Variable $Tiddlertitle
Clear-Variable $ct
Clear-Variable $Tags
Clear-Variable $Fields
}


function Process-Esx ($filelocation, $vcserver) {
###############################################################
## ESX Processing 
## TODO --
##    * vswitch configuration    
#################################
 Write-Host "Parsing: ESX Configuration ======"
# $vmhosts = Get-VMHost | Sort Name | Where-Object {$_.State -eq "Connected"} | Get-View
 $vmhosts = Get-VMHost | Sort Name | Get-View
 $toinject = ""
 
 foreach ($vmhost in $vmhosts){
	$fields = ""
	$cluster = Get-Cluster -VMHost $vmhost.Name
	$Dc = Get-Datacenter -VMHost $vmhost.Name

	$ESXHost = $vmhost.Name
	Write-Host "  processing $ESXHost"
	$Tags="ESX PHYS"
	## Hardware config
	$ct = ""
	$ct += "!Hardware configuration"+$crlf
	$ct += "*Vendor      : "+$vmhost.Summary.hardware.Vendor +$crlf
	$ct += "*Model       : "+$vmhost.Summary.hardware.Model +$crlf
	$ct += "*Memory Size : "+[math]::Round(($vmhost.Summary.hardware.MemorySize)/(1024*1024),2) +$crlf
	$ct += "*Cpu Model   : "+$vmhost.Summary.hardware.CpuModel +$crlf
	$ct += "*Cpu Mhz     : "+$vmhost.Summary.hardware.CpuMhz +$crlf
	$ct += "*Nbr Cpu     : "+$vmhost.Summary.hardware.NumCpuPkgs +$crlf
	$ct += "*Nbr Core    : "+$vmhost.Summary.hardware.NumCpuCores +$crlf
	$ct += "*Nbr Nics    : "+$vmhost.Summary.hardware.NumNics +$crlf
	$ct += "*Nbr Hba     : "+$vmhost.Summary.hardware.NumHbas +$crlf
	
	
	## NETWORK CONFIG
	## 20111106 Add Duplex settings
	$ct +="!!Nic Cards" + $crlf
	$networkSystem = Get-view $vmhost.ConfigManager.NetworkSystem
	foreach($pnic in $networkSystem.NetworkConfig.Pnic){
		$pnicInfo = $networkSystem.QueryNetworkHint($pnic.Device)
		foreach($Hint in $pnicInfo){
			$NetworkInfo = "" | select-Object Host, PNic, Speed, MAC, DeviceID, PortID, Observed, VLAN
			$NetworkInfo.Host = $vmhost.Name
			$NetworkInfo.PNic = $Hint.Device
			$NetworkInfo.DeviceID = $Hint.connectedSwitchPort.DevId
			$NetworkInfo.PortID = $Hint.connectedSwitchPort.PortId
			$record = 0
			Do{
				If ($Hint.Device -eq $vmhost.Config.Network.Pnic[$record].Device){
					$NetworkInfo.Speed = $vmhost.Config.Network.Pnic[$record].LinkSpeed.SpeedMb
					$NetworkInfo.MAC = $vmhost.Config.Network.Pnic[$record].Mac
				}
				$record ++
			}
			Until ($record -eq ($vmhost.Config.Network.Pnic.Length))
			foreach ($obs in $Hint.Subnet){
				$NetworkInfo.Observed += $obs.IpSubnet + " "
				Foreach ($VLAN in $obs.VlanId){
					If ($VLAN -eq $null){
					}
					Else{
						$strVLAN = $VLAN.ToString()
						$NetworkInfo.VLAN += "**"+$strVLAN + " : "+$obs.IpSubnet + $crlf
					}
				}
			}
			$ct += "!!!" + $NetworkInfo.PNic +$crlf
			$ct += "*Speed : " + $NetworkInfo.Speed +$crlf
			$ct += "*FullDuplex : " + $NetworkInfo.FullDuplex +$crlf
			$ct += "*MAC   : " + $NetworkInfo.MAC +$crlf
			$ct += "*Connected switch " +$crlf
			$ct += "**Switch name   : " + $NetworkInfo.DeviceId +$crlf
			$ct += "**Port Id   : " + $NetworkInfo.PortID +$crlf
			$ct += "*VLAN" + $crlf + $NetworkInfo.VLAN
		}
	}

    ## HBA CONFIG
	## V2.2 @20111106
	## inspired from Powercli Reference book
	$ct +="!!HBA" + $crlf
	$ct +="|!Pci|!Device|!Type|!Model|!Status|!Wwpn|"+ $crlf
	foreach ($hba in @($vmhost|Get-VMHostHba){
		$ct +="|"+$hba.Pci+"|"+$hba.Device+"|"+$hba.Type+"|"+$hba.Model+"|"+$hba.Status+"|"+"{0:x}" -f $hba.PortWorldWideName+"|"+ $crlf
	}


	##ESX CONFIG
	## V2.2 console memory
	$ct += "!ESX configuration" + $crlf
	$ct += "*Esx version     : "+$vmhost.Config.Product.Version +$crlf
	$ct += "*Esx Build       : "+$vmhost.Config.Product.Build +$crlf
	$ct += "*Esx Fullname    : "+$vmhost.Config.Product.Fullname +$crlf
	$ct += "*Console Memory  : "+$vmhost.Config.ConsoleReservation.ServiceConsoleReserved / 1MB +$crlf
	$ct += "*Reserved Memory : "+$vmhost.ConfigManager.MemoryManager.ConsoleReservationInfo.ServiceConsoleReserved / 1Mb +$crlf


	## Esx console config (virtu-al)
	$esxnet =Get-VMHostNetwork -VMHost $ESXHost
	$hnet = ( $esxnet | Select ConsoleGateway, DNSAddress -ExpandProperty ConsoleNic | Select PortGroupName, IP, SubnetMask, ConsoleGateway, DNSAddress, Devicename)
	$ct += "!!Console config" +$crlf
	$ct += "*Port group : "+$hnet.PortgroupName +$crlf
	$ct += "*IP : "+$hnet.IP +$crlf
	$ct += "*SubnetMask : "+$hnet.SubnetMask +$crlf
	$ct += "*Gateway : "+$hnet.ConsoleGateway +$crlf
	$ct += "*Dns config : " + $hnet.DNSAddress +$crlf
	$ct += "*Device : " + $hnet.Devicename +$crlf

	## Esx Vmotion config (virtu-al)
	$hvmot =($esxnet| Select VMkernelGateway -ExpandProperty VirtualNic | Where {$_.VMotionEnabled} | Select PortGroupName, IP, SubnetMask, VMkernelGateway, Devicename)
	$ct += "!!Vmotion config" +$crlf
	$ct += "*Port group : "+$hvmot.PortgroupName +$crlf
	$ct += "*IP : "+$hvmot.IP +$crlf
	$ct += "*SubnetMask : "+$hvmot.SubnetMask +$crlf
	$ct += "*Gateway : "+$hvmot.VMKernelGateway +$crlf
	$ct += "*Device : " + $hvmot.Devicename +$crlf

	##Service configuration
	$ct += "!Services configuration" + $crlf
	## NTP
	$ct += "*NTP" + $crlf
	$ct += "**Server : " + (Get-VMHostNtpServer -VMHost $vmhost) + $crlf
	$ct += "**Running : " +((Get-VmHostService -VMHost $vmhost |Where-Object {$_.key-eq "ntpd"}).Running) + $crlf
	
	
	#VSWITCH CONFIG
	$ct += "!Vswitch configuration" + $crlf
	## this part must be totally rewrited so i remove .... maybe in Vxxx
	
	
	##ESX placement
	$ct += "!Location" +$crlf
	$ct += "*Vcenter : [[$vcserver]] " +$crlf
	$ct += "*Datacenter : [[$dc]] " +$crlf
	$ct += "*Cluster : [[$cluster]] " +$crlf
	## Vmware id
	$ct += "!Vmware id" +$crlf
	$ct += "*Moref : "+($vmhost.moref).Tostring() +$crlf
	
    ##build summary fields
	$fields = 'summary="|[['+$ESXHost+']]'
	$fields += '|'+$vmhost.Summary.hardware.Model
	$fields += '|'+[math]::Round(($vmhost.Summary.hardware.MemorySize)/(1024*1024*1024),2)
	$fields += '|'+$vmhost.Summary.hardware.NumCpuPkgs
	$fields += '|'+$vmhost.Summary.hardware.NumCpuCores
	$fields += '|'+$vmhost.Summary.hardware.NumNics
	$fields += '|'+$vmhost.Summary.hardware.NumHbas
	$fields += '|'+$vcserver
	$fields += '|'+$dc
	$fields += '|'+$cluster
	$fields += '|" '
	$fields += 'moref="'+($vmhost.moref).Tostring()+'"'
	
	##Write Tiddler
	$toinject += TiddlerBuild $ESXHost $Tags $fields $ct
	}
##inject tiddler in file
Tiddlyadd $toinject $filelocation

Clear-Variable $ct
Clear-Variable $Tags
Clear-Variable $Fields
}

function Process-Datastore ($filelocation, $vcserver) {
###########################################################################################
## DATASTORE
## TODO ---
## V2.2 Add datastore Type
###########################
Write-Host "Parsing: DataStore ======"
$dssum=""
$toinject=""
$fields=""
$Datastores = (Get-Datastore| sort Name)
$dssum+="|!Datastore|!Space|!Used|!Free|"+$crlf
$tt=0
$tu=0
$tr=0
ForEach ($ds in $Datastores)
{
	$ct=""

	##Get size
	$dt=[math]::Round(($ds.CapacityMB)/1024,2)
	$du=[math]::Round(($ds.CapacityMB - $ds.FreeSpaceMB)/1024,2)
	$dr=[math]::Round($ds.FreeSpaceMB/1024,2)
    ##Summ
	$tt+=$dt
	$tu+=$du
	$tr+=$dr
	
	
	
	$ct+="!" + $Ds.Name + $crlf
	$ct+="Type : "+ $Ds.type + $crlf
	$ct+="Total Capacity (GB) : "+ $dt + $crlf
	$ct+="Used Capacity (GB) : "+ $du + $crlf
	$ct+="Free Capacity (GB) : "+ $dr + $crlf
	$ct+= "!Location" +$crlf
	$ct+= "*VCenter : "+ $vcserver +$crlf
	$ct+= "*Datacenter : " +$crlf


	
	$dssum+="|[["+ $Ds.Name+"]]"
	$dssum+="|"+ $dt
	$dssum+="|"+ $du
	$dssum+="|"+ $dr
	$dssum+="|"+$crlf
	
    ##build summary fields
	$fields = 'summary="'
	$fields += '|[['+$Ds.Name+']]'
	$fields += '|'+$dt
	$fields += '|'+$du
	$fields += '|'+$dr
	$fields += '|" '

	$toinject += TiddlerBuild $Ds.Name "DS" $fields $ct
}
	##inject tiddler in file
	Tiddlyadd $toinject $filelocation
}
	
function Process-Cluster ($filelocation, $vcserver) {	
###########################################################################################
## CLUSTER
## TODO --
##    * Still some error in the drs/ha part
#############################
Write-Host "Parsing Clusters ====="
$toinject = ""
$fields = ""
$clusters = Get-Cluster | Sort Name

ForEach ($cluster in $clusters){
    Write-Host "  Processing $cluster"
	$Tiddlertitle = $cluster
    $Tags = "CLUSTER"
	$ct=""
	$TotalHostMemory=0
    $dc = Get-Datacenter -Cluster $cluster

	$ct+= "!Location" +$crlf
	$ct+= "*VCenter : "+ $vcserver +$crlf
	$ct+= "*Datacenter : "+ $dc +$crlf

	$ct+= "!Configuration" +$crlf
	$ct+= "*DRS :" + $cluster.DRSEnabled +"   Mode: "+ $cluster.DrsAutomationLevel +$crlf
	$ct+= "*HA :" + $cluster.HAEnabled +"   Level: "+ $cluster.HAFailoverLevel +$crlf

	$ct += "!Participant Host" +$crlf
	$vmhosts = (Get-VMHost -Location $cluster | Sort Name) 
	foreach ($vmhost in ($vmhosts|Get-View)){
		$n=$vmhost.Name
		$ct += "*[[$n]]"+$crlf
		$TotalHostMemory += $vmhost.Hardware.MemorySize
	}
	
	$NumHosts = ($vmhosts | Measure-Object).Count 
	$vms = Get-VM -Location $cluster | Where {$_.PowerState -eq "PoweredOn"}
	$NumVMs = $vms.Length
	$TotalRAM_GB = [math]::Round($TotalHostMemory/1GB,$digits)
	
	$TotalVMMemoryMB = $vms | Measure-Object -Property MemoryMB -Sum
	$AssignedRAM_GB = [math]::Round($TotalVMMemoryMB.Sum/1024,$digits)
	$PercentageUsed = [math]::Round((($TotalVMMemoryMB.Sum/1024)/($TotalHostMemory/1GB))*100)		
	$limit = (($NumHosts-1)/$NumHosts*100)

	$ct+= "!Health Overview"+$crlf
	$ct += "*$NumHosts host(s) running $NumVMs virtual machines"+$crlf 
	$ct += "*Total memory resource = $TotalRAM_GB GB"+$crlf  
	$ct += "*Total Amount of assigned memory = $AssignedRAM_GB GB"+$crlf  
	$ct += "*Memory resource percentage allocated = $PercentageUsed % (Safety limit is under $limit %)"+$crlf 
	
	##build summary fields
	$fields = 'summary="|[['+$cluster+']]'
	$fields += '|'+$Numhosts
	$fields += '|'+$NumVMs
	$fields += '|'+$TotalRAM_GB
	$fields += '|'+$AssignedRAM_GB
	$fields += '|'+$PercentageUsed
	$fields += '|'+$limit
	$fields += '|" '
	##Write Tiddler
	$toinject += TiddlerBuild $Tiddlertitle $tags $fields $ct 
}
##inject tiddler in file
Tiddlyadd $toinject $filelocation

Clear-Variable $Tiddlertitle
Clear-Variable $ct
Clear-Variable $Tags
Clear-Variable $toinject
}	

	
function Process-VM ($filelocation, $vcserver) {	
##############################################################################################
## Virtual Machines         
## TODO --
##     * Real physical space of the vm (use top function
##     * Try to reduce the calculation time (14 sec/vm on my infrastructure)
##############################################################################################
Write-Host "Parsing Virtual machines ======"
$toinject = ""
$fields = ""
$cpt=0
if ($vmlimit -eq 0) {
	$vms = (Get-VM | Sort Name)
}
else {
	$vms = (Get-VM | Sort Name| Select-Object -First $vmlimit)
}
ForEach ($vm in $vms)
{
	$fields = ""
	Write-Host "  Processing $vm"
	$vmv = Get-View $vm.ID
	# $vmnics = Get-NetworkAdapter -VM $vm
	# $vmdisks = Get-HardDisk -vm $vm
	$vmname = $vm.name 
	$esx = Get-VMHost -VM $vm
	$cluster = Get-Cluster -VM $vm
	$Dc = Get-Datacenter -VM $vm
	$rpool = Get-ResourcePool -VM $vm
	$vmtotalsize = Get-vmsize $vm

	
	$ct=""
	$Tags = "VM"
	##hardware settings
	$ct += "!Hardware Settings" +$crlf
	$ct += "*Nbr Cpu :" +$vmv.summary.config.numcpu +$crlf
	$ct += "*Memory :" +$vmv.summary.config.memorysizemb +$crlf
	$ct += "*vmx file : "+$vmv.Summary.config.VmPathName +$crlf
	# $ct += "*Total size on datastores :"+$vmtotalsize +$crlf

	##Disk settings
	$tdisk=0
	$ct += "!!Disks" +$crlf
		foreach ($vmdisk in $vm.HardDisks){
		$ct += "*" + $vmdisk.Name +$crlf
		$cap=[math]::Round(($vmdisk.CapacityKB)/(1024*1024),2)
		$ct += "**Capacity (Gb) : "+ $cap + $crlf
		$ct += "**File Name : "+ $vmdisk.Filename +$crlf
		$ct += "**Persistence : " + $vmdisk.Persistence +$crlf
		$tdisk += $cap
		}
		$ct += "*Total capacity : " + $tdisk +$crlf
	
	##Snapshot existence
	$snapshots = Get-SnapShot -VM $vm
	if ($snapshots.Name.Length -ige 1 -or $snapshots.length){
		$ct += "!!Snapshot" +$crlf
		ForEach ($snapshot in $snapshots){
			$ct += "*"+$snapshot.name +$crlf
			$ct += "**Created: "+$snapshot.created +$crlf
			$ct += "**Description : " +$snapshot.description +$crlf
		}
		$Tags += " SNAPSHOT"
	}
	
	## Network settings
	$ct += "!!Network Settings" +$crlf
	$ct += "*Nbr : "+$vmv.summary.config.numEthernetCards +$crlf
	foreach ($vmnic in $vm.NetworkAdapters){
		$ct += "*" + $vmnic.Name +$crlf
		$ct += "**Type : "+ $vmnic.Type + $crlf
		$ct += "**MAC : "+ $vmnic.MacAddress + $crlf
		$ct += "**LAN : "+ $vmnic.NetworkName + $crlf
		$ct += "**Connected : "+ $vmnic.ConnectionState.connected + $crlf
		
		}

	## Guest settings
	$ct += "!Guest Information" +$crlf
	$ct += "Host name : " +$vm.guest.hostname +$crlf
	$ct += "OS Name :"+$vm.guest.OSFullName +$crlf
	$ct += "*Ip Addresses" +$crlf
	$tip = ""
	for  ($i=0; $i -le 9;$i++){
		if ($vm.guest.ipAddress[$i]){
			$ct += "** Ip: " + $vm.guest.ipAddress[$i] + $crlf
			if ($tip -eq ""){
				$tip = $vm.guest.ipAddress[$i]
				}
			else {
				$tip += "," + $vm.guest.ipAddress[$i]
				}
			}
    	}
	$ct += "!Resource Settings" +$crlf
	$ct += "*Power State : " +$vmv.summary.runtime.powerState +$crlf
	$ct += "*Last Boot : " +$vmv.Runtime.BootTime +$crlf
	$ct += "*Memory Limit : " +$vmv.resourceconfig.memoryallocation.limit +$crlf
	$ct += "*Memory Reservation : " + $vmv.resourceconfig.memoryallocation.reservation +$crlf
	$ct += "*Cpu Limit : " + $vmv.resourceconfig.cpuallocation.limit+$crlf
	$ct += "*Cpu Reservation : " +$vmv.resourceconfig.cpuallocation.reservation +$crlf
	$ct += "*Tools Status : " +$vmv.guest.toolsstatus +$crlf
	$ct += "*Tools Version : " +$vmv.config.tools.toolsversion +$crlf
	$ct += "*Hardware version : "+$vmv.Config.Version +$crlf

	##Health check
	## CPU Ready Time
	## from peeteronline.nl 
	$rmk=""
	$ct+= "!Heatlh check"+$crlf
	$Ready = $vm | Get-Stat -Stat Cpu.Ready.Summation -RealTime
	$Used = $vm | Get-Stat -Stat Cpu.Used.Summation -RealTime
	$Wait = $vm | Get-Stat -Stat Cpu.Wait.Summation -RealTime
	For ($a = 0; $a -lt $vm.NumCpu; $a++)
		{
		$ct += "*Cpu $a"+$crlf
		$rdy= [Math]::Round((($Ready | Where {$_.Instance -eq $a} | Measure-Object -Property Value -Average).Average)/200,1)
		if ($rdy -ge $VmCpuReadylimit)
			{$rmk= " !!!! Too high ($VmCpuReadylimit %)"
			$Tags += " CPUREADY"
			}
		$ct+= "**% Ready time : " +$rdy+$rmk+$crlf
	    $ct+= "**% Used : "+[Math]::Round((($Used | Where {$_.Instance -eq $a} | Measure-Object -Property Value -Average).Average)/200,1)+$crlf
		$ct+= "**% Wait : "+ [Math]::Round((($Wait | Where {$_.Instance -eq $a} | Measure-Object -Property Value -Average).Average)/200,1)+$crlf
	}
	
	##Custom fields
	$ct += "!Custom Fields" + $crlf
	for  ($i=0; $i -le $vm.CustomFields.Count-1;$i++){
		$ct += "*"+$vm.CustomFields.Keys[$i] +" : "+ $vm.CustomFields.Values[$i] + $crlf
    	}
	$ct+= "!Location" +$crlf
	$ct+= "*Vcenter : [[$vcserver]] "+$crlf
	$ct+= "*Datacenter : [[$Dc]] "+$crlf
	$ct+= "*Cluster : [[$cluster]]" +$crlf
	$ct+= "*Esx : [[$esx]]" + $crlf
	$ct+= "*Resource Pool : [[$rpool]]"+$crlf
	
		
    ##build summary fields
	$fields = 'summary="'
	$fields += '|[['+$vmname+']]'
	$fields += '|'+$vmv.summary.config.numcpu
	$fields += '|'+[math]::Round(($vmv.summary.config.memorysizemb)/(1024),2)
	$fields += '|'+$tdisk
	$fields += '|'+$vmv.summary.runtime.powerState
	$fields += '|'+$tip
	$fields += '|" '
	$fields += 'moref="'+($vmv.moref).Tostring()+'"'


	##Write Tiddler
	$toinject += TiddlerBuild $vmname $Tags $fields $ct
	$cpt ++
	if ($cpt -eq $savelimit){
		Tiddlyadd $toinject $filelocation
		$toinject =""
		$cpt=0
	}
}

##inject tiddler in file
if ($cpt -gt 0){
	Tiddlyadd $toinject $filelocation
}

Clear-Variable $ct
Clear-Variable $Tags
Clear-Variable $toinject
}


function Process-VCClose ($filelocation, $vcserver, $uc, $Starttime){
#######################################################################################################
## Generation of Info Tiddler
###############################
$Endtime=get-date -Format "yyyy/MM/dd-HH:mm:ss"	
$ttitle = "Generation for "+$vcserver
$tags = "infos"
$fields = ""
$ct = ""
$ct += "!Generation for "+$vcserver+$crlf
$ct += "!!Infrastucture"+ $crlf
$ct += "*Virtual center : " +$vcserver + $crlf
$ct += "*User name : " +$uc + $crlf
$ct += "!!Timing" +$crlf
$ct += "*Start Time : "+$Starttime+$crlf
$ct += "*End Time : "+$Endtime+$crlf
$ct += "!Generator"+$crlf
$ct += "*"+ $pkoversion+$crlf
$ttitle = "Generation for "+$vcserver
$toinject = TiddlerBuild $ttitle $tags $fields $ct
##inject tiddler in file
Tiddlyadd $toinject $filelocation

Clear-Variable $ttitle
Clear-Variable $ct
Clear-Variable $tags
Clear-Variable $toinject
}

########################################################################################################################################
########################################################################################################################################
########################################################################################################################################
### START OF MAIN LOOP
#########################################################
########################################################################################################################################
########################################################################################################################################


##fixed definition
$pkoversion = "TiddlyWikiEsxDoc 2.2 Unclephil-201111 http://tc.unclephil.net"
$crlf="`n"
$Starttime=get-date -Format "yyyy/MM/dd-HH:mm:ss"
$Filetime=get-date -Format "yyyyMMdd-HHmmss"

$ErrorActionPreference = "SilentlyContinue"
$savelimit = 20
$VmCpuReadylimit = 7

################################################################
# VMware PROCESS STARTING  #
############################
 Write-Host "TiddlyWikiEsxDoc"
 Write-Host "Version" $pkoversion
 Write-Host "============================================"

##call parameter files
if ($CFG -eq ""){
    write-host "No parameters provided`nUsing default ./TWEDConfig.ps1 parameters"
	$CFG = "./TWEDConfig.ps1"
}
if (Test-Path $CFG){
	Import-Module $CFG
	Write-Host "File $CFG Loaded"
}
else {
	Write-Host "Parameters file $CFG not found `n"
	Write-Host "TiddlyEsxDoc Stopped"
	break
}


## Calculated variable
$basefile = $curdir+$basetemplate
$reportdir = $curdir + "report"
if ( !(Test-Path $reportdir)) {
	Write-Host "creating $reportdir"
	mkdir $reportdir
	}
$filelocation=$reportdir+"\"+$reportname+"."+$Filetime+".html"
## Delete old result files
del $filelocation

$bf = Get-Content $basefile 
$bf| Set-Content $filelocation

###################
## Display parameters
###################

Write-Host "Environment(s)"
Write-Host "=============="


##################
# Add VI-toolkit #
##################
Write-Host "Initialize VI toolkit"
Add-PSsnapin VMware.VimAutomation.Core
Initialize-VIToolkitEnvironment.ps1

## initialize db title 
Write-Host "Generating title Tiddler ====="
$fields = ""
$ct = $reportname+"."+$Filetime+$crlf
$toinject = TiddlerBuild "CMDBTitle" "" "" $ct
##inject tiddler in file
Tiddlyadd $toinject $filelocation
Clear-Variable $ct
Clear-Variable $Tags
Clear-Variable $toinject

##loop through vcenter array
Write-Host "Vcenter To visit"
Write-Host $vcs
foreach ($vc in $vcs){
	$vs = Connect-VIServer -Server $vc[0] -port $vc[1] -User $vc[2] -Password $vc[3]
	If ($vs.IsConnected -eq $true){	
		Write-host "Connected to " $vc[0] 
		## real processing
		Write-Host "Start Analyzing" $vc[0]
		$st=get-date -Format "yyyy/MM/dd-HH:mm:ss"
		Process-Datacenter $filelocation $vc[0]
		Process-Esx $filelocation $vc[0]
		Process-Datastore $filelocation $vc[0]
		Process-Cluster $filelocation $vc[0]
		Process-VM $filelocation $vc[0]
		Process-VCClose $filelocation $vc[0] $vc[2] $st

		##########################################################
		# Disconnect session from VC #
		##############################
		disconnect-viserver -server $vc[0] -confirm:$false
	}
	else {Write-host "Connect to " $vc[0] ":FAILED"}
}



##########################################################
# E-mail HTML output #
######################
if ($enablemail -match "yes") 
{ 
$msg = new-object Net.Mail.MailMessage
$att = new-object Net.Mail.Attachment($filelocation)
$smtp = new-object Net.Mail.SmtpClient($smtpServer) 
$msg.From = $mailfrom
foreach ($mail in $mailto){
	$msg.To.Add($mail) 
}
$msg.Subject = "TiddlyEsxDoc  from "+$vcserver
$bodytext = "TiddlyEsxDoc for  "+$vcserver
if ($vmlimit -eq 0){ 
	$bodytext += $crlf+ "Complete infrastructure processed"
}
else {
	$bodytext += $crlf+ "Partial infrastructure processed nbr VM: "+$vmlimit
}
$msg.Body = $bodytext
$msg.Attachments.Add($att) 
$smtp.Send($msg)
write-host "Email sended"
}

##########################################################
# PostProcess command #
######################
if ($enablecmd -match "yes") 
{
  $newcmd = $postprocesscmd.Replace("!_FILENAME_!", $filelocation)

  if ($cmddebug -match "yes") {
     write-host "debug The prostprocess command"
     write-host $newcmd
     write-host "VVVVVVVVVVVVVVVV" 
     invoke-expression $newcmd
     write-host "================"
  }
  else
  {
     invoke-expression $newcmd | out-null
  }
}


##########################################################
# Final Cleaning     #
######################
Write-Host "generated file : " $filelocation
Write-Host "  Start time: " $Starttime
Write-Host "  End time: " $Endtime
Write-Host "TiddlyEsxDoc Ended"
##########################
# End Of TiddlyESxDoc.ps1 #
##########################

##ii $filelocation 
