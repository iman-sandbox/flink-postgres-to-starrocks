# 🚀 Flink PostgreSQL to StarRocks CDC Pipeline

This project demonstrates a complete Flink CDC pipeline using:
- 📦 **Debezium** for PostgreSQL Change Data Capture
- 🔄 **Apache Flink** to process and transform changes in real-time
- 📊 **StarRocks** as the analytical sink

## 🧱 Architecture Overview

To render the diagram below, use [Kroki.io](https://kroki.io) or a Markdown PlantUML renderer.

![CDC Pipeline](https://kroki.io/plantuml/svg/eNp1VMFu2zAMvesruJxSFDm1u-wwdI2Tol0CZE2AXXKhbcYWIkuCJK9Lv36U1DjGttxs8_Hx8fElDz6gC32nxKfQUkfgLVaksBQCq2AcFPSLlLHkAH18ETUGLNETTDbGh8bR9sdqr6c78gEKrt1MInLzJCrTWaNJB5gUVNK77DvGfTR5mBfzDD0Xxw1LJfUREvOLKWFaFCu4hZVpZJWbEoDr_zSlhjVqbMgl5Mv6P5gd-uMYtFuP9tqyJa-mOnqWu3RGB9I1T3_E6shPef6AEYJNgdnsKw-CL7yMVebko3RgIT5JvxFi85Qw510Zuehk8PDz2wrmLeqGvBiKEXlekJHsFM9zhB1Mv-PhiDMfToqYdQAN87d9yby5GzYKteDPsbpL6iSfN1QtLH5T1fO-ijJol0HDVox91p5c-BhMdbqtENoEAiebNoA5xCtfQgCeqGbgmwwteOwsk0dT9_q11x6MBmuY8PP93Z2IjkaqvwmHLAxevEW9lI1SpuGbIPdSMq9KxoFPEv1V0iErBR2kztEDKy3xd4qkssqs2ZCYtQ6tlbq5zsmpuuQMyl6qmle0QXbyneq9pmSw5KUbh7b1cHCmi6m4ysgRHKUSXPTMokOlSI35fF8Gxl2Xdonm5ZzLxe3jAmSMWQB2S81YKe11vE-WlhNz4F88C1CnIKvRhAd-4v-IP_NEaq8=)

<details>
<summary>📜 PlantUML Source</summary>

```plantuml
@startuml
!theme spacelab

actor Developer as Dev
database "PostgreSQL\n(Test Data)" as PG
component "Debezium\n(Postgres CDC)" as Debezium
component "Flink SQL\nJob (DDL + Logic)" as FlinkSQL
component "Flink\nJobManager" as JM
component "Flink\nTaskManager" as TM
database "StarRocks\n(Frontend + Backend)" as StarRocks

Dev --> JM : Deploys SQL Jobs (DDL)

PG --> Debezium : Emits WAL Changes
Debezium --> FlinkSQL : CDC Stream (Kafka-style)

FlinkSQL --> JM : Submit Flink Plan
JM --> TM : Dispatch Executable Plan
TM --> StarRocks : Insert Streamed Data

note right of PG
PostgreSQL seeded with sample data\nRuns on port 5433
end note

note right of Debezium
Debezium watches WAL logs\nand emits change streams
end note

note right of FlinkSQL
Defines CDC pipeline logic\nand table DDL mappings
end note

note right of JM
JobManager builds optimized\nexecution graphs from SQL
end note

note right of TM
TaskManager runs parallel\nexecution subtasks
end note

note right of StarRocks
StarRocks FE+BE ingest real-time\ndata from Flink for analytics
end note
@enduml
```

</details>

## 🛠 Components

| Component     | Description                                   |
|---------------|-----------------------------------------------|
| PostgreSQL    | Source DB generating WAL logs for Debezium    |
| Debezium      | Captures WAL logs and produces CDC events     |
| Flink SQL     | Defines pipeline transformations (Flink DDL)  |
| JobManager    | Translates jobs into physical pipelines       |
| TaskManager   | Executes jobs and pushes to StarRocks         |
| StarRocks     | Real-time analytical store                     |

## 🧪 Local Development

```bash
./setup_pipeline.sh
```

> This will:
> - Stop & clean existing containers
> - Download required JARs (Debezium + StarRocks + Runtime)
> - Start PostgreSQL, Flink, and StarRocks containers
> - Deploy SQL CDC pipeline