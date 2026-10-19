# Diversity

The diversity tool measures whether the dataset's wording varies enough for a model to learn the rules rather than fixed phrasings. A writer that repeats sentence patterns, or ties a wording to a label, teaches the model to key on words; the bargaining pilot learned "a line without a number accepts the counter" that way. It is a tool for producing the dataset: a generation batch that fails it is rewritten before it joins a split, but its thresholds add no requirements to the data.

## Usage

```bash
bundle exec ruby bin/diversity batch.csv [--against train.csv] [--embedding-endpoint http://127.0.0.1:1234/v1]
```

| Option                 | Purpose                                                                 |
|------------------------|-------------------------------------------------------------------------|
| `--against`            | Reference split: a new batch must not repeat it, a test split must not leak from it |
| `--embedding-endpoint` | OpenAI-compatible base URL serving an embedding model; without it the semantic check is skipped |
| `--embedding-model`    | Model name sent to the endpoint (default `google/embedding-gemma-300m`) |

It prints a JSON report and exits with code `1` when any check fails.

## Text

The `input` column and the output `message` are measured separately. Before measuring, the item name becomes `@` and every amount becomes `#`, written in digits or in Chinese numerals followed by 金幣, 金, 塊 or 枚, so two lines differing only in item or price count as the same wording.

Lexical similarity is the cosine of character 2–3 gram TF-IDF vectors. Semantic similarity is the cosine of embeddings requested with the `task: sentence similarity | query: ` prefix, and centred on the mean embedding of the measured texts: raw embeddings of short lines all sit above 0.8 and stop telling intents apart.

## Checks

| Check | Measures | Fails when |
|-------|----------|------------|
| `redundant` | Rows repeating an earlier row's normalised text, relationship, and action | Rate above 0.02 |
| `near_duplicate` | Distinct texts whose lexically nearest other text is at least 0.8 similar | Rate above 0.2 |
| `semantic_duplicate` | Distinct texts whose semantically nearest other text is at least 0.9 similar | Rate above 0.2 |
| `against` | Distinct texts at least 0.8 lexically similar to a text in the reference split | Rate above 0.05 |
| `offer_outcome` | Accuracy of predicting a bargaining offer's action from its `input` alone | Above the majority rate by more than 0.05 |

Repeating a line under a different relationship or action is not redundant: such pairs make the model read the state. Whether an offer turn closes a deal depends on the offer and the counter price, not on wording, so `offer_outcome` covers bargaining rows with intent `offer` that are not rude and whose offer differs from the counter price; a high accuracy means the wording gives the outcome away. An offer equal to the counter accepts it, so accepting words there rightly say deal and are left out.

The probe is a multinomial logistic regression over binary character 1–3 grams of the normalised text, trained by SGD with a seeded shuffle and weights averaged over epochs, and scored by 5-fold cross-validation (fold = row position modulo 5). Naive Bayes misses ties a linear model finds, so it is not used. The report also lists, for the input's action, friendship change, and bargaining intent and rude labels, each label's most indicative n-grams with their accuracy against the majority rate. Those are reported, not checked: some wording should decide a label (a threat is refused), so a person reads them for unwanted ties.

## Report

Each check reports its rate, threshold, and `pass`, plus up to five example pairs of nearest texts; the input and message sections also list the five most frequent four-character openings. Checks with nothing to measure (no `--against`, no endpoint, no bargaining offers) are reported as skipped and pass.

## Acceptance Criteria

- `bin/diversity` prints the report as JSON and exits with code `1` when a check fails, `0` otherwise.
- Item names and amounts in digits or Chinese numerals do not distinguish two texts.
- A repeated line with a different relationship or action is not counted as redundant.
- Without `--embedding-endpoint` the semantic check is skipped; an unreachable endpoint prints an error and exits with code `1`.
- The bargaining pilot's phrase-bank turns (`tmp/generation/bargain_train.csv`) fail the report.
