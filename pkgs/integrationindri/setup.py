from setuptools import setup, find_packages

with open("pythonServer/requirements.txt", encoding="utf-16") as f:
    requirements = f.read().splitlines()

setup(
    name="integrationindri",
    version="0.1.0",

    #packages=list(map(lambda name: name.replace("pythonServer", "integrationindri"), find_packages())),
    #package_dir={"integrationindri": "pythonServer"},

    # All of them must be toplevel modules because that's how the server will import them.
    packages=find_packages(where="pythonServer"),
    package_dir={"": "pythonServer"},
    py_modules=["server", "AuthHelper", "integrationindri"],

    install_requires=requirements,
    entry_points={
        "console_scripts": [
            "integrationindri = integrationindri:main",
        ],
    },
)
