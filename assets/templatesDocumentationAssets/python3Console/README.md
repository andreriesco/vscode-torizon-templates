# Python 3 Console template

How to create a virtual enviroment on this template:

 - Press F1
 - Select the command "Python: Create Environment"
 - Select the environment type (venv or conda)
 - Select a Python interpreter (this will be the version installed inside the
 venv)
 - If it doesn't select the Python from the venv, press F1 and select the command
 "Developer: Reload Window")

To install a Python package on the venv (and also on the Debug image), put it 
on the "requirements-debug.txt" file (to install it on the Release image put it
on the "requirements.release.txt" file)

![Create environment command](createEnv.png "createEnvImg")