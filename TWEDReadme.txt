TWED - TiddlyWiki ESX Documenter
================================
Vmware environment documentation in a tidllywiki file

Why 
---
As Architect, i need to maintain the documentation of our datacenter installation
The major part of this one is virtual, powered by VmWare and the best tools to dump documentation is certainly PowerShell and some PSGuru, like LucD, Virtu-al and many others.

On another side, i need a portable documentation of our installation, and for my personal note
For this i use extensively a lot of TiddlyWiki files (www.tiddlywiki.com) stored on my usb key


what's hot
-----------
Multiple configurations files
Multiple vcenter
Analyse ESX, Cluster , Datastore, vm
Send report by mail
Push report on website (via external command)  
It's a wiki, not a DB. You have freetext search, Tagging and many other features. And, if you acquire some experience with tiddlywiki, you can create a kind of cmdb ; your cmdb

What's not
----------
Some element are still missing (vswitch documentation)
It's a wiki, not a DB.... don't try to "Select All vm with ipAddress like 192.168.22.*"
This is my own view of documentation, maybe not yours. 


VERSION 2.0 2011/04/01
=======================
Requirements:
-------------
Powershell V2
PowerCli 4.x


Afterword
==========
If you try to use my script, adapt the TWEDConfig.ps1 file to your needs
The program is only a documenter so you can set a read-only user in the config file

The script will automatically create a report subdirectory where he put his final report

And for the rest, you and you only are responsible of the usage of this program in a production infrastructure.
But in my case i use it every day to create a snapview of my environment

In my case for 2 vcenter, 3 datacenter, 5 cluster, 25 Esx server  and 380 VM the script run during aproximately 45min
If you don't want wait (for test purpose), you can set the $vmlimit counter in the config file

If you have more than one environment, (consultancy case) you can use the program with multiple configfile give the configFilename as parameter


Have fun 

Ph Koenig
Aka UnclePhil