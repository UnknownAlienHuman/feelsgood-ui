const fs = require('fs');
const path = require('path');
const luaparse = require('luaparse');

function walk(dir, done) {
    let results = [];
    fs.readdir(dir, function (err, list) {
        if (err) return done(err);
        let pending = list.length;
        if (!pending) return done(null, results);
        list.forEach(function (file) {
            if (file === 'node_modules' || file === '.git' || file === 'libs') {
                if (!--pending) done(null, results);
                return;
            }
            file = path.resolve(dir, file);
            fs.stat(file, function (err, stat) {
                if (stat && stat.isDirectory()) {
                    walk(file, function (err, res) {
                        results = results.concat(res);
                        if (!--pending) done(null, results);
                    });
                } else {
                    if (file.endsWith('.lua')) {
                        results.push(file);
                    }
                    if (!--pending) done(null, results);
                }
            });
        });
    });
}

walk('.', function (err, results) {
    if (err) throw err;
    let errors = 0;
    for (const file of results) {
        const code = fs.readFileSync(file, 'utf8');
        try {
            luaparse.parse(code, { wait: false, scope: true, locations: true, ranges: true });
        } catch (e) {
            console.error(`SYNTAX ERROR in ${file}:`);
            console.error(e.message);
            const lines = code.split('\n');
            if (e.line) {
                console.error(`> ${lines[e.line - 1]}`);
            }
            errors++;
        }
    }
    if (errors === 0) {
        console.log('All files parsed successfully!');
    } else {
        console.log(`Found ${errors} syntax error(s).`);
    }
});
