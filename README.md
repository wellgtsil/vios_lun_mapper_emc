# vios_lun_mapper_emc

This script was designed to relate EMC luns to its virtualized lpar on IBM PoweVM environments. 

USING IT:

You will have to 
  - edit the script to fill your machine serial and hmc information.
  - setup a ssh trust relation between your VIO and the HMC
  - create a separate dir and execute the script from there
  
TODO:
  - add support to IVM setups
  - remove the use of some temporary files, using variables instead
  - do a script that just print information and another, out of the VIO server, consolidates the information into a csv
  - design an elegant solution to do it remotely and get the information from inside the clients AIX systems
  - make it more vendor independent. Create Modules per vendor and use them as needed
