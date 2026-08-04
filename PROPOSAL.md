# 2026 MoonBit 软件综合挑战赛项目申报书

- **项目名称**：moonbit-injuryrisk (运动损伤风险规则引擎)
- **项目类型**：原创项目 (Original)
- **选手账号**：GitHub: mhh12345678 | GitLink: mhhmhh
- **项目仓库**：
  - GitHub: https://github.com/mhh12345678/moonbit-injuryrisk
  - GitLink: https://gitlink.org.cn/mhhmhh/moonbit-injuryrisk

### 一、 项目简介与应用场景
基于 MoonBit 开发의 轻量级运动状态与损伤风险规则评估引擎。用于运动员日常训练负荷统计（sRPE、ACWR）及睡眠、疲劳、疼痛等物理康复指标监测，提供个性化风险分层和数据解释，规避过度训练造成的软组织损伤。

### 二、 核心功能
1. **滑动窗口指标**：计算 7 日急性负荷、28 日慢性负荷、急性慢性负荷比值（ACWR）、睡眠均值、最大疼痛等。
2. **规则评估 DSL**：支持多指标、多条件、阈值与严重度（High/Medium/Low）配置。
3. **风险报告合成**：自动汇总指标异常，输出可读的风险诊断和科学训练建议。

### 三、 实施方案与交付物
- 交付包含 `types`、`sliding_window`、`engine`、`datasets` 模块的完整 MoonBit 库代码。
- 提供边界值测试套件（覆盖率 100%）及多场景测试数据集与命令行报告 Demo。
- 已配置支持 Windows/macOS/Linux 三端运行 `moon check/test` 的跨平台 GitHub CI。
