download_node() {
  local node_url="http://s3pository.heroku.com/node/v$node_version/node-v$node_version-linux-x64.tar.gz"

  if [ ! -f ${cached_node} ]; then
    info "Downloading node ${node_version}..."
    curl -s ${node_url} -o ${cached_node}
    cleanup_old_node
  else
    info "Using cached node ${node_version}..."
  fi
}

cleanup_old_node() {
  local old_node_path=$cache_path/node-v$old_node-linux-x64.tar.gz


  if [ "$old_node" != "$node_version" ] && [ -f $old_node_path ]; then
    info "Cleaning up old node and old dependencies in cache"
    rm $old_node_path
    rm -rf $cache_path/node_modules

    local bower_components_path=$cache_path/bower_components

    if [ -d $bower_components_path ]; then
      rm -rf $bower_components_path
    fi
  fi
}

install_node() {
  info "Installing node $node_version..."
  tar xzf ${cached_node} -C /tmp

  # Move node (and npm) into .heroku/node and make them executable
  mv /tmp/node-v$node_version-linux-x64/* $heroku_path/node
  chmod +x $heroku_path/node/bin/*
  PATH=$heroku_path/node/bin:$PATH
}

install_npm() {
  # Optionally bootstrap a different npm version
  if [ ! $npm_version ] || [[ `npm --version` == "$npm_version" ]]; then
    info "Using default npm version"
  else
    info "Downloading and installing npm $npm_version (replacing version `npm --version`)..."
    cd $build_path
    npm install --unsafe-perm --quiet -g npm@$npm_version 2>&1 >/dev/null | indent
  fi
}

install_and_cache_npm_deps() {
  info "Installing and caching node modules"
  cd $build_path
  if [ -d $cache_dir/node_modules ]; then
    mkdir -p node_modules
    cp -r $cache_dir/node_modules/* node_modules/
  fi

  npm install --quiet --unsafe-perm --userconfig $build_path/npmrc 2>&1 | indent
  npm rebuild 2>&1 | indent
  npm --unsafe-perm prune 2>&1 | indent
  cp -r node_modules $cache_dir
  PATH=$build_path/node_modules/.bin:$PATH
  install_bower_deps
}

install_bower_deps() {
  cd $build_path
  local bower_json=bower.json

  if [ -f $bower_json ]; then
    info "Installing and caching bower components"

    if [ -d $cache_path/bower_components ]; then
      mkdir -p bower_components
      cp -r $cache_path/bower_components/* bower_components/
    fi
    bower install
    cp -r bower_components $cache_path
  fi
}
