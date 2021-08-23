import pandas as pd
from jinja2 import Environment, PackageLoader, select_autoescape, TemplateNotFound


maturity = {
    "0": "Level 0 - Operator Candidate",
    "1": "Level 1 - Basic Install",
    "2": "Level 2 - Seamless Upgrades",
    "3": "Level 3 - Full Lifecycle",
    "4": "Level 4 - Deep Insights",
    "5": "Level 5 - Auto Pilot"
}


def main():
    env = Environment(
        loader=PackageLoader("maturity_levels"),
        autoescape=select_autoescape()
    )

    df = pd.read_csv("maturity_levels/components.csv")
    for index, row in df.iterrows():
        # service = row['Component'].lower().replace(" ", "_").replace("/", "_")
        service = row['Component']
        filename = service + ".adoc"
        template = service + ".j2"

        try:
            t = env.get_template(template)
            print(filename)
            with open("modules/maturity_levels/pages/operators/" + filename, "w") as f:
                f.write(t.render(row.to_dict()))
        except TemplateNotFound:
            print("No template " + template + " found.")


if __name__ == "__main__":
    main()