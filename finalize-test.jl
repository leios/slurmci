#!/bin/env julia
#
# Usage:
#   finalize-test.jl
#
# Final job for SlurmCI test job set -- requires the environment variable
# CI_SHA to be set to the commit hash of the branch and CI_TOKEN to be set
# to the filename containing the authentication token. Uploads summaries
# and logs to a gist and updates the Github status.

using GitHub

include("src/common.jl")
include("src/slurm_jobs.jl")

function start()
    sha = ENV["CI_SHA"]
    slurmoutdir = joinpath(logdir, sha)

    jobdict = load_jobdict(sha, "test")
    update_status!(jobdict)

    files = Dict("_summary.md" => Dict("content" =>
                                       test_summary(jobdict, sha)))

    for jobid in keys(jobdict)
        filename = joinpath(slurmoutdir, jobid)
        files["out_$jobid"] = Dict("content" => String(read(filename)))
    end

    # authenticate
    auth = authenticate(ENV["CI_TOKEN"])
    repo = GitHub.repo("climate-machine/CLIMA", auth=auth)

    # upload gist
    params = Dict("files" => files,
                  "description" => "SlurmCI $sha",
                  "public" => "true")
    gist = GitHub.create_gist(;auth=auth, params=params)

    # update status
    params = Dict("state" => summary_state(jobdict),
                  "context" => context,
                  "target_url" => string(gist.html_url))

    status = GitHub.create_status(repo, sha;
                                  auth=auth, params=params)
end

start()
