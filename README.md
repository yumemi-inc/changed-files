[![CI](https://github.com/yumemi-inc/changed-files/actions/workflows/ci.yml/badge.svg)](https://github.com/yumemi-inc/changed-files/actions/workflows/ci.yml)

# Changed Files

A GitHub Action that outputs a list of changed files in pull requests and commits.
It is useful when you want to run steps or jobs based on changed files.

## Usage

See [action.yml](action.yml) for available action inputs and outputs.
Note that this action requires `contents: read` permission.

### Supported workflow trigger events

Works on any event.
See [Specify comparison targets](#specify-comparison-targets) for details.

### Use a list of files

Use list of file names from `files` output.

```yaml
- uses: yumemi-inc/changed-files@v3
  id: changed
- run: |
    for file in ${{ steps.changed.outputs.files }}; do
      # do somethihg..
      echo "$file"
    done
```

> **Note:**
> This action only gets a list of file names.
> If you need access to a file, use [actions/checkout](https://github.com/actions/checkout) to check out the files.

By default, they are separated by spaces, but if you want to change the separator, specify it with `separator` input.

```yaml
- uses: yumemi-inc/changed-files@v3
  id: changed
  with:
    separator: ','
```

If you want to output in JSON instead of plain text like above, specify it with `format` input (default is `plain`).

```yaml
- uses: yumemi-inc/changed-files@v3
  id: changed
  with:
    format: 'json'
```

### filter files

The list of files can be filtered by specifying `patterns` input.

```yaml
- uses: yumemi-inc/changed-files@v3
  id: changed
  with:
    patterns: |
      **/*.{yml,yaml}
      !doc/**
```

To filter by file status, specify `statuses` input.

```yaml
- uses: yumemi-inc/changed-files@v3
  id: changed
  with:
    patterns: |
      **/*.{yml,yaml}
      !doc/**
    statuses: 'added'
```

<details>
<summary>about file status</summary>

There are four statuses for changed files: `added`, `modified`, `renamed`, and `removed`.
File statuses are displayed as an icon in pull requests:

![image](doc/status.png)

Note that renamed files will have `renamed` status even if edited.
</details>

To specify multiple statuses, separate them with non-alphabetic characters, such as a space, `,`, and `|`.

```yaml
statuses: 'added|modified|renamed'
```

Alternatively, you can specify statuses to exclude with `exclude-statuses` input.

```yaml
exclude-statuses: 'removed'
```

### Whether a particular file is included

Often we are only interested in whether a particular file is included, not the list of files.
You can check it like `steps.<id>.outputs.files != null` (for JSON, `'[]'` instead of `null`), but you can also use `exists` output.

```yaml
- uses: yumemi-inc/changed-files@v3
  id: changed
  with:
    patterns: '!**/*.md'
- if: steps.changed.outputs.exists == 'true'
  run: # do something..
```

This is useful for controlling step execution.

<details>
<summary>examples</summary>

### Used as test execution condition

```yaml
- uses: actions/checkout@v4
- uses: yumemi-inc/changed-files@v3
  id: changed
  with:
    patterns: '**/*.js'
- if: steps.changed.outputs.exists == 'true'
  run: npm run test
```

#### Add a label to a pull request:

```yaml
- uses: yumemi-inc/changed-files@v3
  id: changed
  with:
    patterns: |
      **/*.js
      !server/**
- env:
    GH_REPO: ${{ github.repository }}
    GH_TOKEN: ${{ github.token }}
  run: |
    gh pr edit ${{ github.event.number }} ${{ steps.changed.outputs.exists == 'true' && '--add-label' || '--remove-label' }} 'frontend'
```

#### Annotate new files in a pull request using workflow commands:

```yaml
- uses: yumemi-inc/changed-files@v3
  id: changed
  with:
    patterns: '**/*.xml'
    statuses: 'added'
- if: steps.changed.outputs.exists == 'true'
  run: |
    for file in ${{ steps.changed.outputs.files }}; do
      echo "::notice file=$file::New XML file added. Please check .."
    done
```

![image](doc/annotation.png)

For more information on workflow commands, see [Workflow commands for GitHub Actions](https://docs.github.com/en/enterprise-cloud@latest/actions/using-workflows/workflow-commands-for-github-actions).

#### Warn with a comment on a pull request:

```yaml
- uses: yumemi-inc/changed-files@v3
  id: changed-src
  with:
    patterns: |
      **/*.{js,ts}
      package.json
- uses: yumemi-inc/changed-files@v3
  id: changed-build
  with:
    patterns: 'dist/**'
- if: steps.changed-src.outputs.exists == 'true' && steps.changed-build.outputs.exists != 'true'
  uses: yumemi-inc/comment-pull-request@v1
  with:
    comment: ':warning: Please check if you forgot to build.'
```

#### Make the job fail:

```yaml
- uses: yumemi-inc/changed-files@v3
  id: changed
  with:
    patterns: 'CHANGELOG.md'
    exclude-statuses: 'removed'
- if: steps.changed.outputs.exists != 'true' && github.base_ref == 'main'
  run: |
    echo "::error::CHANGELOG.md is not updated."
    exit 1
```
</details>

If you just want to run a Bash script, you can use `run` input. In this case, there is no need to define `id:`, since `exists` output is not used.

```yaml
- uses: yumemi-inc/changed-files@v3
  with:
    patterns: '!**/*.md'
    run: # do something..
```

### Use number of changed lines

`changes` output is the total number of changed lines.
This can be used in comparison expressions.

```yaml
- uses: yumemi-inc/changed-files@v3
  id: changed
  with:
    patterns: '!doc/**'
    exclude-statuses: 'removed'
- if: 100 < steps.changed.outputs.changes
  run: # do something..
```

`additions` output and `deletions` output can also be used in the same way (`additions + deletions = changes`).

<details>
<summary>examples</summary>

#### Add a label to a pull request:

```yaml
- uses: yumemi-inc/changed-files@v3
  id: changed
  with:
    patterns: '!doc/**'
    exclude-statuses: 'removed'
- env:
    GH_REPO: ${{ github.repository }}
    GH_TOKEN: ${{ github.token }}
  run: |
    gh pr edit ${{ github.event.number }} ${{ 100 < steps.changed.outputs.changes && '--add-label' || '--remove-label' }} 'large PR'
```

#### Warn with a comment on a pull request:

```yaml
- uses: yumemi-inc/changed-files@v3
  id: changed
  with:
    patterns: '!doc/**'
    exclude-statuses: 'removed'
- if: 100 < steps.changed.outputs.changes
  uses: yumemi-inc/comment-pull-request@v1
  with:
    comment: ':warning: Changes have exceeded 100 lines.'
```
</details>

### Specify comparison targets

Simply, the change files are determined between `head-ref` input and `base-ref` input references.
The default values ​​for each workflow trigger event are as follows:

| event | head-ref | base-ref |
|:---|:---|:---|
| pull_request | github.sha | github.base_ref |
| push | github.sha | github.event.before[^1] / default branch |
| merge_group | github.sha | github.event.merge_group.base_sha |
| other events | github.sha | default branch |

[^1]: Not present on tag push or new branch push. In that case, the default branch will be applied.

Specify these inputs explicitly if necessary.
**Any branch, tag, or commit SHA** can be specified for tease inputs.

```yaml
- uses: yumemi-inc/changed-files@v3
  with:
    head-ref: 'main' # branch to be released
    base-ref: 'release-x.x.x' # previous release tag
    patterns: '**/*.js'
    run: |
      ...
      npm run deploy
```

Note that [three-dot](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/proposing-changes-to-your-work-with-pull-requests/about-comparing-branches-in-pull-requests#three-dot-and-two-dot-git-diff-comparisons) comparison is performed, so `base-ref` must be older than `head-ref` if they are on the same commit line.

> [!WARNING]
> The upper limit for the number of files is `3000` when used with the default value in `pull_request`, `push`, and `merge_group` events (there is a head commit immediately after the base commit, like a merge commit), and `300` otherwise.
> Also, this action does not support comparison with **two-dot**.
> These limitations are because this aciton uses GitHub API.
>
> If these limitations are a problem, use [yumem-inc/path-filter](https://github.com/yumemi-inc/path-filter).
> This has limited functionality as it does not filter by status or output the number of changed lines, but since it does not have the above limitations, it works as a complete path filter.
>
> My recommendation is to use this action, which has many functions, in `pull_request` events.
> There is no problem unless it is a large pull request with `3000` files.
> For other events, you don't need many functions, so use [yumem-inc/path-filter](https://github.com/yumemi-inc/path-filter).

## Tips

### Control job execution

Set this action's `exists` output to the job's output, and reference it in subsequent jobs.

```yaml
outputs:
  exists: ${{ steps.changed.outputs.exists }}
steps:
  - uses: yumemi-inc/changed-files@v3
    id: changed
    with:
      patterns: '**/*.{kt,kts}'
```

<details>
<summary>examples</summary>

#### Run two jobs in parallel, then run a common job:

```yaml
jobs:
  changed:
    runs-on: ubuntu-latest
    permissions:
      contents: read
    outputs:
      exists-src: ${{ steps.changed-src.outputs.exists }}
      exists-doc: ${{ steps.changed-doc.outputs.exists }}
    steps:
      - uses: yumemi-inc/changed-files@v3
        id: changed-src
        with:
          patterns: 'src/**'
      - uses: yumemi-inc/changed-files@v3
        id: changed-doc
        with:
          patterns: 'doc/**'
  job-src:
    needs: [changed]
    if: needs.changed.outputs.exists-src == 'true'
    runs-on: ubuntu-latest
    steps:
      ...
  job-doc:
    needs: [changed]
    if: needs.changed.outputs.exists-doc == 'true'
    runs-on: ubuntu-latest
    steps:
      ...
  job-common:
    needs: [job-src, job-doc]
    # treat skipped jobs as successful
    if: cancelled() != true && contains(needs.*.result, 'failure') == false
    runs-on: ubuntu-latest
    steps:
      ...
```
</details>

### Process output list with JavaScript

Use JSON format output and [actions/github-script](https://github.com/actions/github-script).

```yaml
- uses: yumemi-inc/changed-files@v3
  id: changed
  with:
    format: 'json'
- uses: actions/github-script@v6
  env:
    FILES: ${{ steps.changed.outputs.files }}
  with:
    script: |
      const { FILES } = process.env;
      const files = JSON.parse(FILES);
      files.forEach(file => {
        // do something..
        console.log(file);
      });
```

### Comment to `patterns` input

Characters after `#` are treated as comments.
Therefore, you can write an explanation for the pattern as a comment.

```yaml
- uses: yumemi-inc/changed-files@v3
  id: changed
  with:
    patterns: |
      # sorces
      **/*.{js,css,png}
      !dist/** # exclude built files

      # documents
      doc/**
      !doc/**/*.png # exclude image files
```

### List of changed files and list after filtering

They are output to a file in JSON format and can be accessed as follows:

- `${{ steps.<id>.outputs.action-path }}/files.json`
- `${{ steps.<id>.outputs.action-path }}/filtered_files.json`.

<details>
<summary>more</summary>

Refer to these files when debugging `head-ref`, `base-ref`, and other inputs of filtering conditions.
For example, display them in the job summary like this:

```yaml
- uses: yumemi-inc/changed-files@v3
  id: changed
  with:
    patterns: '!**/*.md'
- run: |
    {
      echo '### files before filtering'
      echo '```json'
      cat '${{ steps.changed.outputs.action-path }}/files.json' | jq
      echo '```'
      echo '### files after filtering'
      echo '```json'
      cat '${{ steps.changed.outputs.action-path }}/filtered_files.json' | jq
      echo '```'
    } >> "$GITHUB_STEP_SUMMARY"
```

You may use these files for purposes other than debugging, but note that these files will be overwritten if you use this action multiple times in the same job.

And, in this action's `run` input, access them with Bash variables like `$GITHUB_ACTION_PATH/files.json`, but note that the Bash script in `run` input will not be executed if there are no files after filtering.
</details>

## About the glob expression of `pattern` input

Basically, it complies with the [minimatch](https://www.npmjs.com/package/minimatch) library used in this action.
Please refer to the implementation in [action.yml](action.yml) for the specified options.
