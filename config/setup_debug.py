import os
import subprocess
import json


def get_modules():
    try:
        result = subprocess.run(
            ["ls", "/workspace/extra-addons"],
            capture_output=True,
            text=True,
            check=True,
        )
        modules = result.stdout.strip().split("\n")
        return ",".join(modules)
    except Exception as e:
        print(f"Error obteniendo módulos: {e}")
        return ""


def update_launch_config(modules):
    launch_path = os.path.join(os.getcwd(), ".vscode", "launch.json")
    with open(launch_path, "r") as f:
        config = json.load(f)

    # Actualiza los argumentos
    for conf in config["configurations"]:
        if conf["name"] == "Python: Odoo":
            conf["args"] = [
                f"-i {modules}",
                f"-u {modules}",
            ]

    with open(launch_path, "w") as f:
        json.dump(config, f, indent=4)


if __name__ == "__main__":
    modules = get_modules()
    print(f"Modulos detectados: {modules}")
    update_launch_config(modules)
