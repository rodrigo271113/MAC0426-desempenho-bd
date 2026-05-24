import matplotlib.pyplot as plt
import pandas as pd

""" Script gerador dos boxplots utilizados no relatório do trabalho """

for file_idx in range(4):
    file_name = f"results/scenario_{file_idx+1}_results.csv"
    try:
        df = pd.read_csv(file_name)
    except FileNotFoundError:
        file_name = f"scenario_{file_idx+1}_results.csv"
        df = pd.read_csv(file_name)

    df.columns = df.columns.str.strip()
    fig, axes = plt.subplots(1, 2, figsize=(14, 6), sharey=True)

    systems = [("MySQL", "mysql"), ("PostgreSQL", "postgres")]

    for i, (display_name, db_value) in enumerate(systems):
        sys_df = df[df["db"].str.lower() == db_value]
        bxp_stats = []

        for idx, (_, row) in enumerate(sys_df.iterrows()):
            mean = row["mean_ms"]
            std = row["stddev_ms"]
            stats = {
                "label": str(idx + 1),
                "med": mean,
                "q1": mean - (0.6745 * std),
                "q3": mean + (0.6745 * std),
                "whislo": mean - std,
                "whishi": mean + std,
            }
            bxp_stats.append(stats)

        if bxp_stats:
            axes[i].bxp(bxp_stats, showfliers=False)

        axes[i].set_title(display_name)
        axes[i].set_xlabel("Id da query (1 - 15)")

    axes[0].set_ylabel("Tempo médio (ms)")
    plt.suptitle(
        f"Performance dos SGBDs - Cenário {file_idx+1} (Média $\pm$ Desvio Padrão)",
        fontsize=14,
        fontweight="bold",
    )
    plt.tight_layout()

    plt.savefig(f"scenario_{file_idx+1}_performance_boxplots.png", dpi=300)
    plt.show()