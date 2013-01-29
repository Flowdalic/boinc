// This file is part of BOINC.
// http://boinc.berkeley.edu
// Copyright (C) 2013 University of California
//
// BOINC is free software; you can redistribute it and/or modify it
// under the terms of the GNU Lesser General Public License
// as published by the Free Software Foundation,
// either version 3 of the License, or (at your option) any later version.
//
// BOINC is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
// See the GNU Lesser General Public License for more details.
//
// You should have received a copy of the GNU Lesser General Public License
// along with BOINC.  If not, see <http://www.gnu.org/licenses/>.

// BOINC GAHP (Grid ASCII Helper Protocol) daemon

// Notes:
// - This is currently Unix-only (mostly because of its use of pthreads)
//   but with some work it could be made to run on Windows

#include <stdio.h>
#include <pthread.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <map>
#include <set>
#include <string>
#include <vector>

#include "md5_file.h"
#include "parse.h"
#include "curl.h"

using std::map;
using std::pair;
using std::set;
using std::string;
using std::vector;

char project_url[256];
char authenticator[256];

bool async_mode = false;

// represents a command.
// if out is NULL the command is in progress;
// otherwise it's the output
//
struct COMMAND {
    char* in;
    char* out;
};

typedef map<int, COMMAND*> COMMANDS;
COMMANDS commands;

int compute_md5(string path, LOCAL_FILE& f) {
    return md5_file(path.c_str(), f.md5, f.nbytes);
}

// Get a list of the input files used by the batch.
// Get their MD5s.
// See if they're already on the server.
// If not, upload them.
//
int process_input_files(SUBMIT_REQ& req) {
    unsigned int i, j;
    int retval;
    char buf[1024];

    // get the set of unique source paths
    //
    set<string> unique_paths;
    for (i=0; i<req.jobs.size(); i++) {
        JOB& job = req.jobs[i];
        for (j=0; j<job.infiles.size(); j++) {
            INFILE infile = job.infiles[j];
            unique_paths.insert(infile.src_path);
        }
    }

    // compute the MD5s of these files,
    // and make a map from path to MD5 and size (LOCAL_FILE)
    //
    set<string>::iterator iter = unique_paths.begin();
    while (iter != unique_paths.end()) {
        string s = *iter;
        LOCAL_FILE lf;
        retval = compute_md5(s, lf);
        if (retval) return retval;
        req.local_files.insert(std::pair<string, LOCAL_FILE>(s, lf));
        iter++;
    }

    // ask the server which files it doesn't already have.
    //
    map<string, LOCAL_FILE>::iterator map_iter;
    map_iter = req.local_files.begin();
    vector<string> md5s, paths;
    vector<int> absent_files;
    while (map_iter != req.local_files.end()) {
        LOCAL_FILE lf = map_iter->second;
        paths.push_back(map_iter->first);
        md5s.push_back(lf.md5);
        iter++;
    }
    retval = query_files(
        project_url,
        authenticator,
        req.batch_id,
        md5s,
        paths,
        absent_files
    );
    if (retval) return retval;

    // upload the missing files.
    //
    vector<string> upload_md5s, upload_paths;
    for (unsigned int i=0; i<absent_files.size(); i++) {
        int j = absent_files[i];
        upload_md5s.push_back(md5s[j]);
        upload_paths.push_back(paths[j]);
    }
    retval = upload_files(
        project_url,
        authenticator,
        req.batch_id,
        upload_md5s,
        upload_paths
    );
    if (retval) return retval;
    return 0;
}

// parse the text coming from Condor
//
int parse_boinc_submit(COMMAND& c, char* p, SUBMIT_REQ& req) {
    strcpy(req.batch_name, strtok_r(NULL, " ", &p));
    strcpy(req.app_name, strtok_r(NULL, " ", &p));
    int njobs = atoi(strtok_r(NULL, " ", &p));
    for (int i=0; i<njobs; i++) {
        JOB job;
        strcpy(job.job_name, strtok_r(NULL, " ", &p));
        int nargs = atoi(strtok_r(NULL, " ", &p));
        for (int j=0; j<nargs; j++) {
            string arg = strtok_r(NULL, " ", &p);
            job.cmdline_args += arg + " ";
        }
        int ninfiles = atoi(strtok_r(NULL, " ", &p));
        for (int j=0; j<ninfiles; j++) {
            INFILE infile;
            strcpy(infile.src_path, strtok_r(NULL, " ", &p));
            strcpy(infile.dst_path, strtok_r(NULL, " ", &p));
            job.infiles.push_back(infile);
        }
        char* q = strtok_r(NULL, " ", &p);
        if (!strcmp(q, "ALL")) {
            job.all_output_files = true;
        } else {
            job.all_output_files = false;
            int noutfiles = atoi(q);
            for (int j=0; j<noutfiles; j++) {
                string outfile = strtok_r(NULL, " ", &p);
                job.outfiles.push_back(outfile);
            }
        }
        req.jobs.push_back(job);
    }
    return 0;
}

// To avoid a race condition with file deletion:
// - create a batch record
// - create batch/file associations, and upload files
// - create jobs
//
void handle_boinc_submit(COMMAND& c, char* p) {
    SUBMIT_REQ req;
    int retval;
    retval = parse_boinc_submit(c, p, req);
    if (retval) {
        printf("error parsing request: %d\n", retval);
        return;
    }
    retval = create_batch(project_url, authenticator, req);
    if (retval) {
        printf("error creating batch: %d\n", retval);
        return;
    }
    retval = process_input_files(req);
    if (retval) {
        printf("error processing input files: %d\n", retval);
        return;
    }
    retval = submit_jobs(project_url, authenticator, req);
    if (retval) {
        printf("error submitting jobs: %d\n", retval);
        return;
    }
    printf("success\n");
}

void* handle_command_aux(void* q) {
    COMMAND &c = *((COMMAND*)q);
    char *p;

    char* cmd = strtok_r(c.in, " ", &p);
    char* id = strtok_r(NULL, " ", &p);
    printf("handling cmd %s\n", cmd);
    if (!strcmp(cmd, "BOINC_SUBMIT")) {
        handle_boinc_submit(c, p);
    } else {
        sleep(10);
        char buf[256];
        sprintf(buf, "handled command %s", c.in);
        c.out = strdup(buf);
    }
    return NULL;
}

int handle_command(COMMAND& c) {
    char cmd[256];
    int id;

    // Handle synchronous commands
    //
    sscanf(c.in, "%s", cmd);
    printf("cmd: %s\n", cmd);
    if (!strcmp(cmd, "VERSION")) {
        printf("1.0\n");
    } else if (!strcmp(cmd, "QUIT")) {
        exit(0);
    } else if (!strcmp(cmd, "RESULTS")) {
        sscanf(c.in, "%s %d", cmd, &id);
        COMMANDS::iterator i = commands.find(id);
        if (i == commands.end()) {
            printf("command %d not found\n", id);
            return 0;
        }
        COMMAND *c2 = i->second;
        if (c2->out) {
            printf("command %d result: %s\n", id, c2->out);
            free(c2->out);
            free(c2->in);
            free(c2);
            commands.erase(i);
        } else {
            printf("command %d not finished\n", id);
        }
        return 0;
    } else {

        // Handle asynchronous commands
        //
        int n = sscanf(c.in, "%s %d", cmd, &id);
        if (n != 2) {
            fprintf(stderr, "invalid command: %s\n", c.in);
            return -1;
        }
        COMMAND *cp = new COMMAND;
        cp->in = c.in;
        cp->out = NULL;
        printf("inserting cmd %d\n", id);
        commands.insert(pair<int, COMMAND*>(id, cp));
        if (async_mode) {
            pthread_t thread_handle;
            pthread_attr_t thread_attrs;
            pthread_attr_init(&thread_attrs);
            pthread_attr_setstacksize(&thread_attrs, 32768);
            int retval = pthread_create(
                &thread_handle, &thread_attrs, &handle_command_aux, cp
            );
            if (retval) {
                fprintf(stderr, "can't create thread\n");
                return -1;
            }
        } else {
            handle_command_aux(cp);
        }
    }
    return 0;
}

// read a line from stdin (possibly very long).
// Return it in a malloc'd buffer
//
char* get_cmd() {
    static const int buf_inc = 16384;
    char* p = (char*)malloc(buf_inc);
    if (!p) return NULL;
    int len = 0;
    int buf_size = buf_inc;
    while (1) {
        char c = fgetc(stdin);
        if (c == EOF) {
            return NULL;
        }
        if (c == '\n') {
            p[len] = 0;
            return p;
        }
        p[len++] = c;
        if (len == buf_size) {
            p = (char*)realloc(p, len+buf_inc);
            buf_size += buf_inc;
        }
    }
}

void read_config() {
    FILE* f = fopen("config.txt", "r");
    if (!f) {
        fprintf(stderr, "no config.txt\n");
        exit(1);
    }
    fgets(project_url, 256, f);
    fgets(authenticator, 256, f);
    fclose(f);
    if (!strlen(project_url)) {
        fprintf(stderr, "no project URL given\n");
        exit(1);
    }
    if (!strlen(authenticator)) {
        fprintf(stderr, "no authenticator given\n");
        exit(1);
    }
}

int main() {
    char* p;
    int retval;
    read_config();
    while (1) {
        p = get_cmd();
        if (p == NULL) break;
        COMMAND c;
        c.in = p;
        retval = handle_command(c);
        if (retval) break;
    }
}
